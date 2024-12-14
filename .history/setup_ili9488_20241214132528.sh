#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo ./setup_tft.sh" 
   exit 1
fi

# Introduction and confirmation
clear
echo "TFT 4\" Setup Script for ILI9488 on Raspberry Pi 4B"
echo "Tested in December 2024 for TFT 4\" displays with dimensions 480x320."
echo "This process involves modifying system files, downloading files, and installing dependencies."
echo "These changes may affect the functionality of your Raspberry Pi."
echo "At the end of the process, your Raspberry Pi will automatically reboot."
echo
read -p "Do you authorize this process and accept full responsibility for any changes? (Y/N): " user_input
if [[ "$user_input" != "Y" && "$user_input" != "y" ]]; then
    echo "No changes have been made. Process aborted."
    exit 0
fi

# Begin setup
echo "Starting TFT setup..."

# Update system and install dependencies
echo "Updating the system and installing dependencies..."
apt update && apt upgrade -y
apt install -y cmake git build-essential nano

# Configure fbcp-ili9341
echo "Downloading and configuring fbcp-ili9341..."
cd ~
if [ ! -d "fbcp-ili9341" ]; then
    git clone https://github.com/juj/fbcp-ili9341.git
fi
cd fbcp-ili9341
mkdir -p build
cd build
rm -rf *
cmake -DUSE_GPU=ON -DSPI_BUS_CLOCK_DIVISOR=12 \
      -DGPIO_TFT_DATA_CONTROL=25 -DGPIO_TFT_RESET_PIN=17 \
      -DILI9488=ON -DUSE_DMA_TRANSFERS=OFF ..
make -j$(nproc)
sudo install fbcp-ili9341 /usr/local/bin/

# Prompt before modifying config.txt
echo
echo "The script will now modify the Raspberry Pi configuration file (config.txt)."
echo "Existing lines that are changed will be commented with a note."
read -p "Do you accept these changes and wish to proceed? (Y/N): " config_input
if [[ "$config_input" != "Y" && "$config_input" != "y" ]]; then
    echo "No changes have been made to the configuration file. Process aborted."
    exit 0
fi

# Define the configuration file path
CONFIG_FILE="/boot/firmware/config.txt"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="/boot/config.txt"
fi

update_config() {
    local key=$1
    local value=$2

    # Check if the line already exists
    if grep -q "^$key" "$CONFIG_FILE"; then
        # Remove any preceding # and update value if necessary
        sed -i "s/^#$key/$key/" "$CONFIG_FILE"
        if [ -n "$value" ]; then
            sed -i "s|^$key.*|$key=$value|" "$CONFIG_FILE"
        fi
    else
        # Add the line if it doesn't exist
        if [ -z "$value" ]; then
            echo "$key" >> "$CONFIG_FILE"
        else
            echo "$key=$value" >> "$CONFIG_FILE"
        fi
    fi
}

# Comment the line max_framebuffers=2 if it exists
if grep -q "^max_framebuffers=2" "$CONFIG_FILE"; then
    sed -i "s|^max_framebuffers=2|#max_framebuffers=2 (line commented for TFT ILI9488 installation on $(date +%m/%d/%Y))|" "$CONFIG_FILE"
fi

# Comment the dtoverlay=vc4-kms-v3d line
sed -i "s|^dtoverlay=vc4-kms-v3d|#dtoverlay=vc4-kms-v3d (line commented for TFT ILI9488 installation on $(date +%m/%d/%Y))|" "$CONFIG_FILE"

# Add required configuration lines
echo "#Modifications for ILI9488 installation implemented by the script on $(date +%m/%d/%Y)" >> "$CONFIG_FILE"
update_config "dtoverlay" "spi0-0cs"
update_config "dtparam" "spi=on"
update_config "hdmi_force_hotplug" "1"
update_config "hdmi_cvt" "480 320 60 1 0 0 0"
update_config "hdmi_group" "2"
update_config "hdmi_mode" "87"
update_config "framebuffer_width" "480"
update_config "framebuffer_height" "320"
update_config "dtoverlay" "fbtft_device,name=ili9488,rotate=0,fps=30,speed=16000000"
update_config "dtparam" "dc_pin=22"
update_config "dtparam" "reset_pin=11"
update_config "gpu_mem" "128"
echo "# Utilized for TFT ILI9488 setup script by AdamoMD" >> "$CONFIG_FILE"
echo "# https://github.com/adamomd/4inchILI9488RpiScript/" >> "$CONFIG_FILE"
echo "# Feel free to send feedback and suggestions." >> "$CONFIG_FILE"

# Configure sudoers for fbcp-ili9341
echo "Setting permissions in sudoers..."
VISUDO_FILE="/etc/sudoers.d/fbcp-ili9341"
if [ ! -f "$VISUDO_FILE" ]; then
    echo "ALL ALL=(ALL) NOPASSWD: /usr/local/bin/fbcp-ili9341" > "$VISUDO_FILE"
    chmod 440 "$VISUDO_FILE"
fi

# Set binary permissions
echo "Configuring permissions for fbcp-ili9341..."
chmod u+s /usr/local/bin/fbcp-ili9341

# Configure rc.local to start fbcp-ili9341
echo "Configuring /etc/rc.local..."
RC_LOCAL="/etc/rc.local"
if [ ! -f "$RC_LOCAL" ]; then
    cat <<EOT > "$RC_LOCAL"
#!/bin/bash
# rc.local
# This script is executed at the end of each multi-user runlevel.

# Start fbcp-ili9341
/usr/local/bin/fbcp-ili9341 >> /var/log/fbcp-ili9341.log 2>&1 &

exit 0
EOT
    chmod +x "$RC_LOCAL"
else
    if ! grep -q "fbcp-ili9341" "$RC_LOCAL"; then
        sed -i '/exit 0/i \\n# Start fbcp-ili9341\n/usr/local/bin/fbcp-ili9341 >> /var/log/fbcp-ili9341.log 2>&1 &' "$RC_LOCAL"
    fi
fi

# Finish and force reboot
echo "Finalizing processes..."
killall -9 fbcp-ili9341 2>/dev/null || true
sync

echo -e "\nSetup complete. The Raspberry Pi will now reboot."
sudo reboot