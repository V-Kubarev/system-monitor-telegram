# System Monitor Telegram

A simple but effective set of bash scripts for monitoring a Linux server's vital signs and sending alerts to a Telegram chat.

This project was created to provide a lightweight, dependency-minimal monitoring solution that is easy to set up and understand.

## Features

- **CPU Monitoring:** Tracks overall CPU usage and alerts on sustained high load.
- **Memory Monitoring:** Tracks memory usage and alerts when it exceeds a threshold.
- **Disk Monitoring:** Tracks disk space usage for the root filesystem.
- **Network Monitoring:** Tracks total network traffic (RX + TX) in KB/s.
- **Connectivity Check:** Periodically pings a set of reliable hosts to ensure the server has external internet connectivity.
- **Telegram Alerts:** Sends immediate, clear notifications to a specified Telegram chat when any threshold is breached or connectivity is lost.

## Components

- `monitor.sh`: The core script that runs every minute to gather system metrics.
- `notifier.sh`: A companion script that watches the alert log and dispatches notifications.
- `telegram.conf.example`: An example configuration file for your Telegram credentials.
- `systemd/`: A directory containing example `systemd` service files to run the scripts as background services.

## Dependencies

Before you begin, ensure the following tools are installed on your server. On Debian/Ubuntu, you can install them with `apt-get`.

- `curl`: Used to send messages to the Telegram API.
- `bc`: A command-line calculator, used for metric calculations.
- `sysstat`: Provides the `sar` command, which is essential for gathering CPU and network statistics.

```bash
sudo apt-get update
sudo apt-get install -y curl bc sysstat
```

## Installation & Configuration

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/YOUR_USERNAME/system-monitor-telegram.git
    cd system-monitor-telegram
    ```
    (Or, just copy the files from this project into a directory on your server, e.g., `/opt/system-monitor-telegram/`)

2.  **Configure Telegram**
    - Create a `telegram.conf` file from the example:
      ```bash
      cp telegram.conf.example telegram.conf
      ```
    - Edit `telegram.conf` with a text editor.
    - You will need a **Bot Token** (get one by talking to `@BotFather` on Telegram) and your **Chat ID** (get it by talking to `@userinfobot`).
    - Fill in these values in the `telegram.conf` file.

3.  **Make Scripts Executable**
    - The scripts need to have execute permissions.
      ```bash
      chmod +x monitor.sh notifier.sh
      ```

4.  **Set up Systemd Services**
    - The `systemd` directory contains example service files. You need to edit them to point to the correct script location.
    - Let's assume you placed the scripts in `/opt/system-monitor-telegram/`.
      ```bash
      # Edit both service files
      nano systemd/monitor.service.example
      nano systemd/notifier.service.example
      ```
    - In both files, change the `/path/to/your/scripts/` placeholder to the actual directory, e.g., `/opt/system-monitor-telegram/`.
    - Copy the edited files to the systemd directory:
      ```bash
      sudo cp systemd/monitor.service.example /etc/systemd/system/monitor.service
      sudo cp systemd/notifier.service.example /etc/systemd/system/notifier.service
      ```
    - Reload the systemd daemon to make it aware of the new services:
      ```bash
      sudo systemctl daemon-reload
      ```
    - Enable and start the services:
      ```bash
      sudo systemctl enable --now monitor.service notifier.service
      ```

## Usage

Once the services are running, the monitoring starts automatically.
- A `system_load.log` file will be created, logging metrics every minute.
- An `alerts.log` file will be created, logging only when a threshold is breached.
- You will receive a "Notifier service started" message in your Telegram chat, confirming that the setup is working.

You can check the status of the services at any time with:
```bash
sudo systemctl status monitor.service
sudo systemctl status notifier.service
```
