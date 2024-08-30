#!/bin/bash

# Variables
JAR_PATH="/opt/java-app"
SERVICE_FILE="/etc/systemd/system/java-app.service"
LOG_FILE="/var/log/java-app-deployment.log"

# Function to get the latest and previous JAR files
get_versions() {
    # Get the latest and second latest JAR files
    LATEST_JAR=$(ls -t ${JAR_PATH}/demo-*.jar 2>/dev/null | head -n 1)  # Most recent JAR file
    PREVIOUS_JAR=$(ls -t ${JAR_PATH}/demo-*.jar 2>/dev/null | head -n 2 | tail -n 1)  # Second most recent JAR file
    
    # Extract version numbers
    LATEST_VERSION=$(basename ${LATEST_JAR} | sed 's/demo-\(.*\)-SNAPSHOT.jar/\1/')
    PREVIOUS_VERSION=$(basename ${PREVIOUS_JAR} | sed 's/demo-\(.*\)-SNAPSHOT.jar/\1/')
}

# Function to update systemd configuration
update_systemd_config() {
    local jar_file=$1
    echo "Updating systemd configuration to use $jar_file..." | tee -a ${LOG_FILE}
    
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
    get_versions
    if [ -z "$PREVIOUS_JAR" ]; then
        echo "No previous version available for rollback. Manual intervention required." | tee -a ${LOG_FILE}
        exit 1
    fi

    echo "Rolling back to previous version: ${PREVIOUS_JAR} (Version: ${PREVIOUS_VERSION})" | tee -a ${LOG_FILE}
    sudo -n ln -sf ${PREVIOUS_JAR} "${JAR_PATH}/demo-latest.jar"
    update_systemd_config ${PREVIOUS_JAR}
    sudo -n systemctl restart java-app.service

    if sudo -n systemctl is-active --quiet java-app.service; then
        echo "Rollback to version ${PREVIOUS_VERSION} succeeded!" | tee -a ${LOG_FILE}
    else
        echo "Rollback failed! Manual intervention required." | tee -a ${LOG_FILE}
        exit 1
    fi
}

# Main deployment logic
deploy() {
    NEW_VERSION=$1
    NEW_VERSION_JAR="${JAR_PATH}/demo-${NEW_VERSION}-SNAPSHOT.jar"
    
    if [ ! -f "${NEW_VERSION_JAR}" ]; then
        echo "Specified version ${NEW_VERSION_JAR} does not exist. Exiting." | tee -a ${LOG_FILE}
        exit 1
    fi

    get_versions

    # Update symbolic links and backups
    echo "Deploying new version: ${NEW_VERSION_JAR}" | tee -a ${LOG_FILE}
    if [ -n "$LATEST_JAR" ]; then
        sudo -n mv ${LATEST_JAR} ${JAR_PATH}/demo-previous.jar  # Backup the current latest as previous
    fi
    sudo -n ln -sf ${NEW_VERSION_JAR} "${JAR_PATH}/demo-latest.jar"  # Set new jar as the latest
    
    update_systemd_config ${NEW_VERSION_JAR}

    # Start or restart the service
    sudo -n systemctl restart java-app.service

    # Check if the service started successfully
    if ! sudo -n systemctl is-active --quiet java-app.service; then
        echo "Deployment of version ${NEW_VERSION} failed! Rolling back..." | tee -a ${LOG_FILE}
        rollback
    else
        echo "Deployment of version ${NEW_VERSION} succeeded!" | tee -a ${LOG_FILE}
    fi
}

# Execute deployment or rollback based on the argument
if [ "$1" == "rollback" ]; then
    rollback
else
    deploy "$1"
fi
