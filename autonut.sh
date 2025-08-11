#!/bin/bash

echo "=== NUT Linux Server Auto Setup + WinNUT Config Generator ==="
echo

# 1. Detect UPS with nut-scanner
echo "Running nut-scanner -U to find UPS..."
SCAN_RESULT=$(sudo nut-scanner -U 2>/dev/null)

get_value() {
    echo "$SCAN_RESULT" | grep "^$1 =" | head -n1 | awk -F '"' '{print $2}'
}
driver=$(get_value driver)
port=$(get_value port)
vendorid=$(get_value vendorid)
productid=$(get_value productid)
desc=$(get_value desc)

# Set defaults if detection fails
driver=${driver:-nutdrv_qx}
port=${port:-auto}
vendorid=${vendorid:-0665}
productid=${productid:-5161}
desc=${desc:-"My UPS"}

echo "Detected:"
echo " Driver: $driver"
echo " Port: $port"
echo " Vendor ID: $vendorid"
echo " Product ID: $productid"
echo " Description: $desc"
echo

read -p "Enter UPS name (default: myups): " ups_name
ups_name=${ups_name:-myups}

read -p "Enter UPS driver (default: $driver): " driver_input
driver=${driver_input:-$driver}

read -p "Enter UPS port (default: $port): " port_input
port=${port_input:-$port}

read -p "Enter vendorid (default: $vendorid): " vendorid_input
vendorid=${vendorid_input:-$vendorid}

read -p "Enter productid (default: $productid): " productid_input
productid=${productid_input:-$productid}

read -p "Enter UPS description (default: \"$desc\"): " desc_input
desc=${desc_input:-$desc}

read -s -p "Enter NUT admin password: " admin_password
echo
read -s -p "Enter NUT slave password: " slave_password
echo

read -p "Enter FINALDELAY in seconds (default: 180): " finaldelay
finaldelay=${finaldelay:-180}

# Create config files
echo "Creating /etc/nut/ups.conf"
sudo tee /etc/nut/ups.conf > /dev/null <<EOF
[$ups_name]
  driver = $driver
  port = $port
  vendorid = $vendorid
  productid = $productid
  desc = "$desc"
EOF

echo "Creating /etc/nut/upsd.conf"
sudo tee /etc/nut/upsd.conf > /dev/null <<EOF
LISTEN 0.0.0.0 3493
EOF

echo "Creating /etc/nut/upsd.users"
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

echo "Creating /etc/nut/upsmon.conf"
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
