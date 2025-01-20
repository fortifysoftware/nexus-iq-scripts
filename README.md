# Nexus IQ Scripts for Linux
These scripts were created and tested on Ubuntu 24. YMMV.

## Installation
To download the installation script from a terminal, run

```bash
cd ~/Downloads/
curl -L "https://github.com/fortifysoftware/nexus-iq-scripts/raw/refs/heads/main/install-iq.sh" -o install-iq.sh
chmod u+x install-iq.sh
```

Before running the script, make sure Java 17 is installed on the system. You may want to modify the value of the `JAVA_PATH` variable on line 5 to explicitly set the absolute path to the java executable (e.g., `JAVA_PATH="/usr/lib/jvm/jdk-17/bin/java"`).

To run the installation script, run

```bash
sudo ./install-iq.sh
```

## Uninstallation
To download the uninstallation script from a terminal, run

```bash
cd ~/Downloads/
curl -L "https://github.com/fortifysoftware/nexus-iq-scripts/raw/refs/heads/main/uninstall-iq.sh" -o uninstall-iq.sh
chmod u+x uninstall-iq.sh
```

Before running the script, make sure the environment variables defined under the `Variables` section are consistent with those in the installation script.

To run the uninstallation script, run

```bash
sudo ./uninstall-iq.sh
```
