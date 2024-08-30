#!/bin/bash

# Variables
JAR_PATH="/opt/java-app"
SERVICE_FILE="/etc/systemd/system/java-app.service"
LOG_FILE="/var/log/java-app-deployment.log"

# Detect the latest and previous JAR files
LATEST_JAR=$(ls -t ${JAR_PATH}/demo-*.jar | head -n 1)  # Most recent JAR file
PREVIOUS_JAR=$(ls -t ${JAR_PATH}/demo-*.jar | head -n 2 | tail -n 1)  # Second most recent JAR file

# Function to update systemd configuration
update_systemd_config() {
    local jar_file=$1
    echo "Updating systemd configuration to use $jar_file..." | tee -a ${LOG_FILE}
    
    sudo -n tee ${SERVICE_FILE} > /dev/null <<EOL
[Unit]
Description=Java Application Service
After=network.target

[Service]
ExecStart=/bin/java -jar ${jar_file}
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
    echo "Rolling back to previous version..." | tee -a ${LOG_FILE}
    sudo -n ln -sf ${PREVIOUS_JAR} "${JAR_PATH}/demo-latest.jar"
    update_systemd_config ${PREVIOUS_JAR}
    sudo -n systemctl restart java-app.service

    if sudo -n systemctl is-active --quiet java-app.service; then
        echo "Rollback succeeded!" | tee -a ${LOG_FILE}
    else
        echo "Rollback failed! Manual intervention required." | tee -a ${LOG_FILE}
    fi
}

if [ "$1" == "rollback" ]; then
    rollback
else
    # Deploy the new version
    NEW_VERSION_JAR="${JAR_PATH}/demo-$1-SNAPSHOT.jar"
    
    # Update symbolic links
    echo "Deploying new version: ${NEW_VERSION_JAR}" | tee -a ${LOG_FILE}
    sudo -n mv ${LATEST_JAR} ${JAR_PATH}/demo-previous.jar  # Backup the current latest as previous
    sudo -n ln -sf ${NEW_VERSION_JAR} "${JAR_PATH}/demo-latest.jar"  # Set new jar as the latest
    
    update_systemd_config ${NEW_VERSION_JAR}

    # Start or restart the service
    sudo -n systemctl restart java-app.service

    # Check if the service started successfully
    if ! sudo -n systemctl is-active --quiet java-app.service; then
        echo "Deployment failed! Rolling back..." | tee -a ${LOG_FILE}
        rollback
    else
        echo "Deployment of version $1 succeeded!" | tee -a ${LOG_FILE}
    fi
fi
