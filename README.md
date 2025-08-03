# NUT UPS Server & WinNUT Client Setup

This repository contains **step-by-step instructions, configuration examples, and automation scripts** for setting up a reliable UPS monitoring and shutdown system using Network UPS Tools (NUT) on a Raspberry Pi, with Windows PC clients running **WinNUT** for UPS status monitoring and automated shutdown.

It also covers:

- Creating appropriate udev USB rules to allow NUT to access the UPS device.
- Configuring the NUT server (`nut-server` and `nut-monitor`) on Raspberry Pi.
- Setting up WinNUT client on Windows with automatic admin startup.
- Deploying a modern web-based UPS monitoring dashboard using `nut_webgui` Docker container.
- Scripts to automate server-side setup and generate Windows client config files.

---

## Features

- Auto-detection of UPS via `nut-scanner` for server config.
- Secure user management with admin and slave roles.
- Networked UPS data serving over TCP port `3493`.
- Windows WinNUT client configuration generator for quick setup.
- USB permission management with udev rules.
- Dockerized `nut_webgui` for visual UPS monitoring accessible via web browser.
- Support for graceful shutdown sequences with configurable delays.

---

## Requirements

- Raspberry Pi running Raspberry Pi OS (Debian-based)
- USB-connected UPS
- Windows PC for WinNUT client
- Docker installed on Raspberry Pi (for web UI)
- Network connectivity between Pi and Windows clients

---

## Setup Overview

### 1. Raspberry Pi NUT Server

- Install NUT packages.
- Use the included bash script (`nut_autosetup.sh`) to auto-detect UPS, prompt for credentials, and generate config files.
- Reload udev rules and restart NUT services.

### 2. Windows PC WinNUT Client

- Install WinNUT Client.
- Use the generated `WinNUTClient.ini` configuration block for seamless connection.
- Set WinNUT to run as administrator automatically (via Task Scheduler recommended).

### 3. nut_webgui Dashboard (Optional)

- Run the `nut_webgui` Docker container for a modern UPS monitoring web UI.
- Connect via `http://<pi-ip>:9000` or configured port.

---

## Usage

- Test UPS with:
