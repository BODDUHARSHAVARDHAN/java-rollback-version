#!/bin/bash

# Variables
JAR_PATH="/opt/java-app"
SERVICE_FILE="/etc/systemd/system/java-app.service"
LOG_FILE="/var/log/java-app-deployment.log"

# Detect the latest and previous JAR files
LATEST_JAR=$(ls -t ${JAR_PATH}/demo-latest.jar 2>/dev/null)  # Most recent JAR file (linked as latest)
PREVIOUS_JAR=$(ls -t ${JAR_PATH}/demo-previous.jar 2>/dev/null)  # Previous JAR file (linked as previous)

# Function to update systemd configuration
update_systemd_config() {
    local jar_file=$1
    echo "Updating systemd configuration to use $jar_file..." | tee -a ${LOG_FILE}
    
    sudo -n tee ${SERVICE_FILE} > /dev/null <<EOL
[Unit]
Description=Java Application Service
After=network.target

[Service]
ExecStart=bin/java -jar ${jar_file}
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
    if [ -z "$PREVIOUS_JAR" ]; then
        echo "No previous version available for rollback. Manual intervention required." | tee -a ${LOG_FILE}
        exit 1
    fi

    echo "Rolling back to previous version: ${PREVIOUS_JAR}" | tee -a ${LOG_FILE}
    sudo -n ln -sf ${PREVIOUS_JAR} "${JAR_PATH}/demo-latest.jar"
    update_systemd_config ${PREVIOUS_JAR}
    sudo -n systemctl restart java-app.service

    if sudo -n systemctl is-active --quiet java-app.service; then
        echo "Rollback succeeded!" | tee -a ${LOG_FILE}
    else
        echo "Rollback failed! Manual intervention required." | tee -a ${LOG_FILE}
    fi
}

# Main deployment logic
deploy() {
    NEW_VERSION_JAR="${JAR_PATH}/demo-$1-SNAPSHOT.jar"
    
    if [ ! -f "${NEW_VERSION_JAR}" ]; then
        echo "Specified version ${NEW_VERSION_JAR} does not exist. Exiting." | tee -a ${LOG_FILE}
        exit 1
    fi

    # If this is the first deployment, just link the new version as latest
    if [ -z "$LATEST_JAR" ]; then
        echo "First deployment: Linking ${NEW_VERSION_JAR} as the latest version." | tee -a ${LOG_FILE}
        sudo -n ln -sf ${NEW_VERSION_JAR} "${JAR_PATH}/demo-latest.jar"
        update_systemd_config ${NEW_VERSION_JAR}
    else
        # Backup the current latest as previous
        echo "Deploying new version: ${NEW_VERSION_JAR}" | tee -a ${LOG_FILE}
        sudo -n cp ${LATEST_JAR} ${JAR_PATH}/demo-previous.jar
        
        # Set new jar as the latest
        sudo -n ln -sf ${NEW_VERSION_JAR} "${JAR_PATH}/demo-latest.jar"
        update_systemd_config ${NEW_VERSION_JAR}
    fi

    # Restart the service
    sudo -n systemctl restart java-app.service

    # Check if the service started successfully
    if ! sudo -n systemctl is-active --quiet java-app.service; then
        echo "Deployment of version $1 failed! Rolling back..." | tee -a ${LOG_FILE}
        rollback
    else
        echo "Deployment of version $1 succeeded!" | tee -a ${LOG_FILE}
    fi
}

# Execute deployment or rollback based on the argument
if [ "$1" == "rollback" ]; then
    rollback
else
    deploy "$1"
fi
