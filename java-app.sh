#!/bin/bash

# Variables
JAR_PATH="/opt/java-app"
SYMLINK_LATEST="${JAR_PATH}/demo-latest.jar"
SYMLINK_PREVIOUS="${JAR_PATH}/demo-previous.jar"
SERVICE_FILE="/etc/systemd/system/java-app.service"

# Function to update systemd configuration
update_systemd_config() {
    local jar_file=$1
    echo "Updating systemd configuration to use $jar_file..."
    
   sudo tee ${SERVICE_FILE} > /dev/null <<EOL
[Unit]
Description=Java Application Service
After=network.target

[Service]
ExecStart=/usr/bin/java -jar ${jar_file}
User=harsha
Restart=always

[Install]
WantedBy=multi-user.target
EOL

   sudo systemctl daemon-reload
   sudo systemctl enable java-app.service
}

if [ "$1" == "rollback" ]; then
    # Rollback: Switch to the previous version
    echo "Rolling back to previous version..."
    sudo ln -sf ${SYMLINK_PREVIOUS} ${SYMLINK_LATEST}
    update_systemd_config ${SYMLINK_LATEST}
else
    # Normal Deployment: Use the new version
    NEW_JAR="${JAR_PATH}/demo-$1-SNAPSHOT.jar"
    
    # Update symbolic links
    echo "Deploying new version: ${NEW_JAR}"
    sudo mv ${SYMLINK_LATEST} ${SYMLINK_PREVIOUS}  # Backup the current latest as previous
    sudo ln -sf ${NEW_JAR} ${SYMLINK_LATEST}  # Set new jar as the latest
    
    update_systemd_config ${SYMLINK_LATEST}
fi

# Start or restart the service
sudo systemctl restart java-app.service
