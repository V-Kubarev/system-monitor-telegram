#!/bin/bash
# ==============================================================================
#
#          FILE: monitor.sh
# 
#         USAGE: ./monitor.sh
# 
#   DESCRIPTION: A comprehensive system monitoring script that periodically
#                gathers metrics on CPU, disk, memory, and network usage,
#                as well as external connectivity. It logs these metrics
#                and generates alerts if they exceed predefined thresholds.
# 
#     DEPENDS: sysstat (for sar), bc
# 
# ==============================================================================

# --- Configuration ---
# File to store all periodic system load metrics.
LOG_FILE="system_load.log"
# File to store alert messages for breached thresholds.
ALERT_FILE="alerts.log"
# File to log details of processes running during a CPU spike.
CPU_SPIKE_LOG="cpu_spike_details.log"
# Interval in seconds between each monitoring check.
INTERVAL=60

# --- Thresholds ---
# The script will generate an alert if any of these values are exceeded.
CPU_THRESHOLD=80    # percent
DISK_THRESHOLD=60   # percent
MEM_THRESHOLD=80    # percent
NET_THRESHOLD=102400 # KB/s (equivalent to 100 MB/s)

# --- Connectivity Check ---
# A list of reliable public hosts to ping to check for internet connectivity.
CHECK_HOSTS=("8.8.8.8" "1.1.1.1" "1.0.0.1" "9.9.9.9")

# --- Network Monitoring ---
# The network interface to monitor. Use 'ip a' or 'ifconfig' to find yours.
NET_INTERFACE="eth0"


# --- Main Loop ---
echo "Starting system monitor..."
echo "--- Monitor started at $(date) ---" >> $LOG_FILE
echo "--- Monitor started at $(date) ---" >> $ALERT_FILE

# The script runs in an infinite loop to monitor the system continuously.
while true
do
    # Get a consistent timestamp for the current check.
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

    # --- 1. CPU Usage ---
    # Gathers CPU idle percentage from `sar` (part of sysstat package).
    # The result is subtracted from 100 to get the total usage percentage.
    CPU_IDLE=$(sar 1 1 | grep "Average:" | awk '{print $NF}')
    # If `sar` fails, default to 100% idle (0% usage) to prevent errors.
    CPU_IDLE=${CPU_IDLE:-100} 
    CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc | awk -F. '{print $1}')

    # --- 2. Disk Usage ---
    # Gathers the usage percentage for the root filesystem (/).
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    # If `df` fails, default to 0 to prevent errors.
    DISK_USAGE=${DISK_USAGE:-0}

    # --- 3. Memory Usage ---
    # Gathers memory usage in megabytes and calculates the used percentage.
    MEM_USAGE=$(free -m | awk 'NR==2 {print $3*100/$2}' | awk -F. '{print $1}')
    # If `free` fails, default to 0 to prevent errors.
    MEM_USAGE=${MEM_USAGE:-0}

    # --- 4. Network Usage ---
    # Gathers network statistics (receive and transmit) for the specified interface.
    NET_STATS=$(sar -n DEV 1 1 | grep "Average:" | grep $NET_INTERFACE)
    NET_RX=$(echo "$NET_STATS" | awk '{print $5}')
    NET_TX=$(echo "$NET_STATS" | awk '{print $6}')
    # If `sar` fails, default to 0 to prevent errors.
    NET_RX=${NET_RX:-0} 
    NET_TX=${NET_TX:-0} 
    # Calculate the total network traffic (upload + download) in KB/s.
    NET_TOTAL_KB=$(echo "$NET_RX + $NET_TX" | bc | awk -F. '{print $1}')
    
    # --- 5. Connectivity ---
    # Pings each host in the CHECK_HOSTS array to verify external connectivity.
    CONNECTIVITY_STATUS="OK"
    for host in "${CHECK_HOSTS[@]}"; do
        # -c 1: send 1 packet, -W 2: wait 2 seconds for a response.
        if ! ping -c 1 -W 2 "$host" &> /dev/null; then
            CONNECTIVITY_STATUS="FAIL"
            # If a host is unreachable, log an alert immediately.
            echo "[$TIMESTAMP] CONNECTIVITY ALERT: Host $host is unreachable." >> $ALERT_FILE
        fi
    done

    # --- Log Current Stats ---
    # Appends a single line with all gathered metrics for the current interval to the log file.
    echo "$TIMESTAMP | CPU: $CPU_USAGE% | Disk: $DISK_USAGE% | Mem: $MEM_USAGE% | Net: $NET_TOTAL_KB KB/s | Connectivity: $CONNECTIVITY_STATUS" >> $LOG_FILE

    # --- Check for Threshold Breaches ---
    # Compares the gathered metrics against the predefined thresholds.
    # If a threshold is breached, a descriptive alert is written to the alert log.

    if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" |bc -l) )); then
        echo "[$TIMESTAMP] CPU ALERT: Usage is $CPU_USAGE%, exceeding threshold of $CPU_THRESHOLD%." >> $ALERT_FILE
        # If CPU usage is high, log the top 5 processes to a separate file for later analysis.
        {
            echo "--- Top Processes during CPU spike at $TIMESTAMP (Usage: $CPU_USAGE%) ---"
            ps aux --sort=-%cpu | head -n 6
            echo "--- End of list ---"
            echo ""
        } >> "$CPU_SPIKE_LOG"
    fi

    if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
        echo "[$TIMESTAMP] DISK ALERT: Usage is $DISK_USAGE%, exceeding threshold of $DISK_THRESHOLD%." >> $ALERT_FILE
    fi

    if [ "$MEM_USAGE" -gt "$MEM_THRESHOLD" ]; then
        echo "[$TIMESTAMP] MEMORY ALERT: Usage is $MEM_USAGE%, exceeding threshold of $MEM_THRESHOLD%." >> $ALERT_FILE
    fi

    if (( $(echo "$NET_TOTAL_KB > $NET_THRESHOLD" |bc -l) )); then
        echo "[$TIMESTAMP] NETWORK ALERT: Usage is $NET_TOTAL_KB KB/s, exceeding threshold of $NET_THRESHOLD KB/s." >> $ALERT_FILE
    fi

    # --- Wait for the next interval ---
    # The script pauses for the duration specified in the INTERVAL variable.
    sleep $INTERVAL
done
