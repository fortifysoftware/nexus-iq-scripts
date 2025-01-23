#!/bin/bash

# Variables
JAVA_VERSION="17" # As of this writing, Nexus IQ server requires Java 17 to run
JAVA_PATH="" # Specify absolute path to Java executable here. If not defined, will attempt to locate an instance.
NEXUS_IQ_URL="https://download.sonatype.com/clm/server/latest.tar.gz"
INSTALL_DIR="/opt/sonatype/nexus/iq"
NEXUS_USER="nexus"
NEXUS_HOME="/home/$NEXUS_USER"
NEXUS_IQ_WORK_DIR="$NEXUS_HOME/iq"
LOG_FILE="/var/log/nexus-iq.log"
SERVICE_NAME="nexus-iq"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
CONFIG_FILE="config.yml"

# If you need to specify a proxy server to reach external sites,
# please uncomment the below and specify the appropriate proxy server.
# export http_proxy="http://user:pwd@127.0.0.1:1234"
# export https_proxy="http://user:pwd@127.0.0.1:1234"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Check for Java 17 if JAVA_PATH not predefined
if [[ -z $JAVA_PATH ]]; then
    echo "Checking for Java $JAVA_VERSION..."
    JAVA_PATH=$(find /usr/lib/jvm/ -maxdepth 1 -type d -o -type l -name "*$JAVA_VERSION*" -exec find -L {} -type f -executable -name "java" \; -quit)
fi

# Check if JAVA_PATH is accidentally set to a directory
if [ -d $JAVA_PATH ]; then
    echo "JAVA_PATH is accidentally set to a directory. Assuming it is the directory containing Java $JAVA_VERSION. Searching for java executable..."
    JAVA_PATH=$(find -L $JAVA_PATH -type f -executable -name "java" -print -quit)
fi

# Verify Java path
if [[ -z "$JAVA_PATH" || ! ( -f "$JAVA_PATH" && -x "$JAVA_PATH" ) ]]; then
    echo "Java $JAVA_VERSION not found or not executable."
    echo "Please install Java $JAVA_VERSION or specify the absolute path to the java executable in the JAVA_PATH variable."
    exit 1
fi

# Verify Java version
JAVA_INSTALLED_VERSION=$($JAVA_PATH -version 2>&1 | grep -P -o -m1 '(?<=version \")[0-9]+')
if [ "$JAVA_INSTALLED_VERSION" != "$JAVA_VERSION" ]; then
  echo "Incorrect Java version found. Please install Java $JAVA_VERSION. Exiting..."
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
    useradd -r -m -s /sbin/nologin -d $NEXUS_HOME -c "Sonatype Nexus system (non-login) account" "$NEXUS_USER"
fi

# Add current user to nexus group
echo "Adding the current user to the $NEXUS_USER group..."
usermod -aG "$NEXUS_USER" "$(logname)"

# Create necessary directories
echo "Creating necessary directories under $NEXUS_IQ_WORK_DIR..."
mkdir -p "$NEXUS_IQ_WORK_DIR/conf" "$NEXUS_IQ_WORK_DIR/log" "$NEXUS_IQ_WORK_DIR/work"

# Move config.yml to NEXUS_IQ_WORK_DIR/conf
echo "Moving $CONFIG_FILE to $NEXUS_IQ_WORK_DIR/conf..."
mv "$INSTALL_DIR/$CONFIG_FILE" "$NEXUS_IQ_WORK_DIR/conf/"

# Change ownership
echo "Changing ownership of $NEXUS_IQ_WORK_DIR to $NEXUS_USER..."
chown -R "$NEXUS_USER":"$NEXUS_USER" "$NEXUS_IQ_WORK_DIR"
echo "Changing ownership of $INSTALL_DIR to root..."
chown -R root:root "$INSTALL_DIR"

# Update paths in config.yml
echo "Updating paths in config.yml..."
sed -i 's#/sonatype-work#/work#g' "$NEXUS_IQ_WORK_DIR/conf/$CONFIG_FILE"

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
WorkingDirectory=$NEXUS_IQ_WORK_DIR
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
echo -e "❗\e[1mIMPORTANT\e[0m❗"
echo "  ‾‾‾‾‾‾‾‾‾"
echo -e "• You may want to configure the file \e[1m$NEXUS_IQ_WORK_DIR/conf/$CONFIG_FILE\e[0m before"
echo "  starting the service. Note that the working directory of the service is"
echo -e "  \e[1m$NEXUS_IQ_WORK_DIR\e[0m. Therefore, all relative paths specified in \e[1m$CONFIG_FILE\e[0m"
echo -e "  are relative to this working directory (\e[1m$NEXUS_IQ_WORK_DIR\e[0m)."
echo -e "• The default HTTP port is \e[1;36m8070\e[0m. This can be changed in \e[1m$CONFIG_FILE\e[0m."
echo "• The server is configured by default with an inbuilt H2 database which"
echo "  is not recommended for enterprise deployments. Enterprise self-hosted"
echo "  deployments need to use an external PostgreSQL database. For configuration"
echo "  details, please refer to:"
echo "  🔗 https://help.sonatype.com/en/external-database-configuration.html"
echo -e "• The license file can either be specified in \e[1m$CONFIG_FILE\e[0m or uploaded"
echo "  to the server the first time you login with the admin account."
echo -e "• To start the service after configuring \e[1m$CONFIG_FILE\e[0m, run:"
echo -e "  🚀 \e[1;35msudo\e[0m \e[1;36msystemctl start \e[1m$SERVICE_NAME\e[0m"
echo -e "• Standard output and error can be found at \e[1m$LOG_FILE\e[0m"
echo -e "• Server logs can be found under \e[1m$NEXUS_IQ_WORK_DIR/log\e[0m"
echo -e "• The default username is: \e[1;31madmin\e[0m"
echo -e "• The default password is: \e[1;31madmin123\e[0m"
