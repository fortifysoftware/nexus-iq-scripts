#!/bin/bash

# Variables
INSTALL_DIR="/opt/sonatype/nexus/iq"
NEXUS_USER="nexus"
NEXUS_HOME="/home/nexus/iq"
LOG_FILE="/var/log/nexus-iq.log"
SERVICE_NAME="nexus-iq"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Stop the service
echo "Stopping the service..."
systemctl stop $SERVICE_NAME

# Disable the service
echo "Disabling the service..."
systemctl disable $SERVICE_NAME

# Remove current user from nexus group
echo "Removing current user $(logname) from the $NEXUS_USER group..."
gpasswd -d "$(logname)" "$NEXUS_USER"

# Remove nexus user and nexus home directory
echo "Deleting the user $NEXUS_USER and its home directory..."
userdel -r "$NEXUS_USER"

# Remove standard output log
echo "Deleting $LOG_FILE..."
rm "$LOG_FILE"

# Remove service file
echo "Deleting the service file..."
rm "$SERVICE_FILE"

# Reload systemd
echo "Reloading systemd..."
systemctl daemon-reload

# Delete installation directory
echo "Deleting installation directory $INSTALL_DIR"
rm -rf "$INSTALL_DIR"

# Final message
echo "✅ Uninstall complete!"
