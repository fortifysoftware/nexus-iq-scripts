#!/bin/bash

# Variables
LATEST_URL="https://download.sonatype.com/clm/server/latest.tar.gz"
INSTALL_DIR=/opt/sonatype/nexus/iq/
SERVICE_NAME="nexus-iq"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# If you need to specify a proxy server to reach external sites,
# please uncomment the below and specify the appropriate proxy server.
# export http_proxy="http://user:pwd@127.0.0.1:1234"
# export https_proxy="http://user:pwd@127.0.0.1:1234"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Determine installed version
OLDJAR=$(find $INSTALL_DIR -name "nexus-iq*")
OLDVERSION=$(echo $OLDJAR | grep -P -o "(?<=server-1\.)[0-9]+")
if [ -z "${OLDVERSION}" ]
then
    echo "Unable to determine the installed version. Exiting..."
    exit
fi

# Determine redirected download URL and new version
echo "Looking up latest version of Nexus IQ..."
DOWNLOAD_URL=$(curl -v "$LATEST_URL" 2>&1 | grep -P -o -m1 '(?<=[lL]ocation: )https:[-\./0-9a-zA-Z]+\.tar\.gz')
NEWVERSION=$(echo $DOWNLOAD_URL | grep -P -o '(?<=server-1\.)[0-9]+')
if [ -z "${NEWVERSION}" ]
then
    echo "Unable to determine the latest version from the download URL. Exiting..."
    exit
fi
echo -e "Installed Nexus IQ version: \e[1;31m$OLDVERSION\e[0m"
echo -e "Latest Nexus IQ version: \e[1;36m$NEWVERSION\e[0m"
if [ $NEWVERSION = $OLDVERSION ]
then
    echo "Installed version is current. Exiting..."
    exit
fi

# Stop the service
echo "Stopping Nexus IQ service..."
systemctl stop nexus-iq

# Delete old .jar file
echo "Deleting older Nexus IQ jar file..."
rm $OLDJAR

# Download the latest version of Nexus IQ server
echo "Downloading latest version..."
curl -O --output-dir "$INSTALL_DIR" "$DOWNLOAD_URL"

# Extract the jar file
echo "Extracting latest jar file..."
FILENAME=$(find $INSTALL_DIR -name "*.tar.gz")
tar xzf $FILENAME -C $INSTALL_DIR --wildcards nexus-iq-server*.jar

# Remove the .tar.gz file
echo Removing $FILENAME
rm $FILENAME

# Update ownership on new .jar file
echo Updating ownership on new jar file...
chown -R root:root "$INSTALL_DIR"

# Update the service file
echo Updating service file...
OLDJAR=$(echo $OLDJAR | xargs -n 1 basename)
NEWJAR=$(find $INSTALL_DIR -name "nexus-iq*" | xargs -n 1 basename)
sed -i "s/$OLDJAR/$NEWJAR/" "$SERVICE_FILE"

# Reload systemd
echo "Reloading systemd..."
systemctl daemon-reload

# Start the service
echo "Starting Nexus IQ service..."
systemctl start nexus-iq
