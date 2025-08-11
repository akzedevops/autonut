#!/bin/bash

set -e
set -u

echo "=== NUT Linux Server Auto Setup + WinNUT Config Generator ==="
echo

#--- Functions ---#

# Print error and exit
die() { echo "Error: $*" >&2; exit 1; }

# Prompt for value with default
prompt() {
    local var="$1" prompt="$2" default="$3"
    read -r -p "$prompt (default: $default): " input
    export "$var"="${input:-$default}"
}

# Prompt for password securely
prompt_pass() {
    local var="$1" prompt="$2"
    read -r -s -p "$prompt: " input
    echo
    export "$var"="$input"
}

# Detect UPS with nut-scanner
detect_ups() {
    echo "Running nut-scanner -U to find UPS..."
    local scan
    scan=$(sudo nut-scanner -U 2>/dev/null || true)
    get_value() { echo "$scan" | grep "^$1 =" | head -n1 | awk -F '"' '{print $2}'; }
    
    DETECTED_DRIVER=$(get_value driver)
    DETECTED_PORT=$(get_value port)
    DETECTED_VENDORID=$(get_value vendorid)
    DETECTED_PRODUCTID=$(get_value productid)
    DETECTED_DESC=$(get_value desc)
    
    export DETECTED_DRIVER DETECTED_PORT DETECTED_VENDORID DETECTED_PRODUCTID DETECTED_DESC
}

#--- Main ---#

detect_ups

driver="${DETECTED_DRIVER:-nutdrv_qx}"
port="${DETECTED_PORT:-auto}"
vendorid="${DETECTED_VENDORID:-0665}"
productid="${DETECTED_PRODUCTID:-5161}"
desc="${DETECTED_DESC:-My UPS}"

echo "Detected:"
echo " Driver: $driver"
echo " Port: $port"
echo " Vendor ID: $vendorid"
echo " Product ID: $productid"
echo " Description: $desc"
echo

prompt ups_name "Enter UPS name" "myups"
prompt driver "Enter UPS driver" "$driver"
prompt port "Enter UPS port" "$port"
prompt vendorid "Enter vendorid" "$vendorid"
prompt productid "Enter productid" "$productid"
prompt desc "Enter UPS description" "$desc"
prompt_pass admin_password "Enter NUT admin password"
prompt_pass slave_password "Enter NUT slave password"
prompt finaldelay "Enter FINALDELAY in seconds" "180"

#--- Confirm ---
echo
echo "======= CONFIGURATION SUMMARY ======="
echo "UPS Name: $ups_name"
echo "Driver: $driver"
echo "Port: $port"
echo "Vendor ID: $vendorid"
echo "Product ID: $productid"
echo "Description: $desc"
echo "FINALDELAY: $finaldelay"
echo

read -r -p "Proceed with configuration? (y/N): " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || die "Aborted."

#--- Create NUT config files ---#

sudo tee /etc/nut/ups.conf > /dev/null <<EOF
[$ups_name]
  driver = $driver
  port = $port
  vendorid = $vendorid
  productid = $productid
  desc = "$desc"
EOF

sudo tee /etc/nut/upsd.conf > /dev/null <<EOF
LISTEN 0.0.0.0 3493
EOF

sudo tee /etc/nut/upsd.users > /dev/null <<EOF
[admin]
  password = $admin_password
  actions = SET
  actions = FSD
  instcmds = ALL

[slave]
  password = $slave_password
  upsmon slave
EOF

sudo tee /etc/nut/upsmon.conf > /dev/null <<EOF
MONITOR $ups_name@localhost 1 admin $admin_password primary
FINALDELAY $finaldelay
EOF

echo "Setting NUT mode to netserver in /etc/nut/nut.conf"
echo "MODE=netserver" | sudo tee /etc/nut/nut.conf > /dev/null

echo "Creating udev rule for USB permissions"
sudo tee /etc/udev/rules.d/62-nut-usbups.rules > /dev/null <<EOF
ATTR{idVendor}=="$vendorid", ATTR{idProduct}=="$productid", MODE="664", GROUP="nut"
EOF

echo "Reloading udev rules"
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "Restarting and enabling NUT services"
sudo systemctl restart nut-server nut-monitor
sudo systemctl enable nut-server nut-monitor

echo
echo "=== LINUX NUT CONFIGURATION COMPLETED! ==="
echo "Test UPS using: upsc $ups_name"
echo

# ----- Windows WinNUTClient.ini generator -----
echo "------ WINNUT CLIENT CONFIGURATION (Copy This To WinNUTClient.ini on Windows) ------"
cat <<EOWIN
[WinNUT]
NUTHost=$(hostname -I | awk '{print $1}')
NUTPort=3493
UPSName=$ups_name
Login=slave
Password=$slave_password

PollingInterval=1
TypeOfStop=1
DelayToShutdown=30
AllowExtendedShutdownDelay=False
ExtendedShutdownDelay=15

MinInputVoltage=210
MaxInputVoltage=270
MinInputFrequency=40
MaxInputFrequency=60

ShutdownLimitBatteryCharge=30
ShutdownLimitUPSRemainTime=120

MinimizeToTray=True
StartWithWindows=True
UseLogFile=False
LogLevel=0
AutoReconnect=True
EOWIN

echo "----------------------------------------------------------------------------------"
echo "Copy the above block and paste it to WinNUTClient.ini on your Windows PC."
echo "You can now configure both sides (server and client) quickly and correctly!"
