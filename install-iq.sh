#!/bin/bash

# Variables
JAVA_VERSION="17" # As of this writing, Nexus IQ server requires Java 17 to run
JAVA_PATH="/usr/lib/jvm/jdk-17/bin/java" # Specify absolute path to Java executable here. If not defined, will attempt to locate an instance.
NEXUS_IQ_URL="https://download.sonatype.com/clm/server/latest.tar.gz"
INSTALL_DIR="/opt/sonatype/nexus/iq"
NEXUS_USER="nexus"
NEXUS_HOME="/home/nexus/iq"
LOG_FILE="/var/log/nexus-iq.log"
SERVICE_NAME="nexus-iq"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
CONFIG_FILE="config.yml"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Check for Java 17
if [[ -z $JAVA_PATH ]]; then
    echo "Checking for Java $JAVA_VERSION..."
    JAVA_PATH=$(update-alternatives --list java | grep "$JAVA_VERSION" | head -n 1)
    if [[ -z $JAVA_PATH ]]; then
        JAVA_PATH=$(command -v java)
        if [[ -n $JAVA_PATH ]]; then
            JAVA_VERSION_CHECK=$("$JAVA_PATH" -version 2>&1 | grep "version" | grep "$JAVA_VERSION")
            if [[ -z $JAVA_VERSION_CHECK ]]; then
                JAVA_PATH=""
            fi
        fi
    fi
fi

# Verify Java path
if [[ -z $JAVA_PATH || ! -x $JAVA_PATH ]]; then
    echo "Java $JAVA_VERSION not found or not executable. Please install Java $JAVA_VERSION or specify its path at the top of the script."
    exit 1
fi

echo "Using Java path: $JAVA_PATH"

# Create installation directory
echo "Creating installation directory at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR" || { echo "Failed to create directory $INSTALL_DIR."; exit 1; }

# Download IQ server tarball
echo "Downloading Nexus IQ Server from $NEXUS_IQ_URL..."
curl -L -o "$INSTALL_DIR/latest.tar.gz" "$NEXUS_IQ_URL"
if [[ $? -ne 0 ]]; then
    echo "Failed to download Nexus IQ Server. Exiting."
    exit 1
fi

# Extract required files
echo "Extracting files..."
tar -xzf "$INSTALL_DIR/latest.tar.gz" -C "$INSTALL_DIR" --wildcards --no-anchored "nexus-iq-server-*.jar" "$CONFIG_FILE"
if [[ $? -ne 0 ]]; then
    echo "Extraction failed. Exiting."
    exit 1
fi
rm -f "$INSTALL_DIR/latest.tar.gz"

# Check for and create nexus user
if ! id "$NEXUS_USER" &>/dev/null; then
    echo "Creating system user '$NEXUS_USER'..."
    useradd -r -m -s /sbin/nologin -c "Sonatype Nexus system (non-login) account" "$NEXUS_USER"
fi

# Add current user to nexus group
echo "Adding the current user to the $NEXUS_USER group..."
usermod -aG "$NEXUS_USER" "$(logname)"

# Create necessary directories
echo "Creating necessary directories under $NEXUS_HOME..."
mkdir -p "$NEXUS_HOME/conf" "$NEXUS_HOME/log" "$NEXUS_HOME/work"
chown -R "$NEXUS_USER":"$NEXUS_USER" "$NEXUS_HOME"

# Move config.yml to /home/nexus/iq/conf/
echo "Moving $CONFIG_FILE to $NEXUS_HOME/conf..."
mv "$INSTALL_DIR/$CONFIG_FILE" "$NEXUS_HOME/conf/"
chown "$NEXUS_USER":"$NEXUS_USER" "$NEXUS_HOME/conf/$CONFIG_FILE"

# Update paths in config.yml
echo "Updating paths in config.yml..."
sed -i 's#/sonatype-work#/work#g' "$NEXUS_HOME/conf/$CONFIG_FILE"

# Determine jar file name
JAR_FILE=$(find "$INSTALL_DIR" -name "nexus-iq-server-*.jar" -type f -print -quit)
if [[ -z $JAR_FILE ]]; then
    echo "Nexus IQ Server jar file not found. Exiting."
    exit 1
fi
JAR_NAME=$(basename "$JAR_FILE")

# Create systemd service file
echo "Creating systemd service file at $SERVICE_FILE..."
cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Sonatype Nexus IQ Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$NEXUS_HOME
ExecStart=$JAVA_PATH -Xmx10G -jar $INSTALL_DIR/$JAR_NAME server conf/config.yml
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
User=$NEXUS_USER
Group=$NEXUS_USER
TimeoutStopSec=5
SuccessExitStatus=0 143

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chmod 644 "$SERVICE_FILE"

# Reload systemd and enable the service
echo "Reloading systemd and enabling the service..."
systemctl daemon-reload
systemctl enable nexus-iq

# Final messages
echo -e "\n✅ Nexus IQ Server installation is complete! 🍻\n"
echo "❗IMPORTANT❗"
echo "  ‾‾‾‾‾‾‾‾‾"
echo "• Please configure the file $NEXUS_HOME/conf/$CONFIG_FILE before starting the service."
echo "• Note that the default HTTP port is 8070."
echo "• To start the service after configuring $CONFIG_FILE, run: sudo systemctl start $SERVICE_NAME"
echo "• Standard output (including standard error) can be found at $LOG_FILE"
echo "• Server logs can be found under $NEXUS_HOME/log"
echo "• The default username is: admin"
echo "• The default password is: admin123"
