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
    
    sudo -n tee ${SERVICE_FILE} > /dev/null <<EOL
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

    sudo -n systemctl daemon-reload
    sudo -n systemctl enable java-app.service
}

# Function to handle rollback
rollback() {
    echo "Rolling back to previous version..."
    sudo -n ln -sf ${SYMLINK_PREVIOUS} ${SYMLINK_LATEST}
    update_systemd_config ${SYMLINK_PREVIOUS}
    sudo -n systemctl restart java-app.service

    if sudo -n systemctl is-active --quiet java-app.service; then
        echo "Rollback succeeded!"
    else
        echo "Rollback failed! Manual intervention required."
    fi
}

if [ "$1" == "rollback" ]; then
    rollback
else
    # Normal Deployment: Use the new version
    NEW_JAR="${JAR_PATH}/demo-$1-version.jar"
    
    # Update symbolic links
    echo "Deploying new version: ${NEW_JAR}"
    sudo -n mv ${SYMLINK_LATEST} ${SYMLINK_PREVIOUS}  # Backup the current latest as previous
    sudo -n ln -sf ${NEW_JAR} ${SYMLINK_LATEST}  # Set new jar as the latest
    
    # Deliberately fail the deployment for version 0.0.2
    if [ "$1" == "0.0.2" ]; then
        echo "Intentionally setting an invalid path for demo-0.0.2-version.jar to simulate failure..."
        update_systemd_config "/invalid/path/to/demo-0.0.2-version.jar"
    else
        update_systemd_config ${SYMLINK_LATEST}
    fi

    # Start or restart the service
    sudo -n systemctl restart java-app.service

    # Check if the service started successfully
    if ! sudo -n systemctl is-active --quiet java-app.service; then
        echo "Deployment failed! Rolling back..."
        rollback
    else
        echo "Deployment of version $1 succeeded!"
    fi
fi
