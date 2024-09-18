#!/bin/sh
SERVICE_NAME=shipper-application.jar
SYMLINK_PATH=/opt/java-app/latest.jar
PREVIOUS_SYMLINK_PATH=/opt/java-app/previous.jar
PID_PATH_NAME=/tmp/shipper-application.jar-pid
LOG_PATH=/var/log/stage/shipper-application.log

start_service() {
    echo "Starting $SERVICE_NAME ..."
    if [ ! -f $PID_PATH_NAME ]; then
        nohup java -jar $SYMLINK_PATH --spring.config.location=/home/fleetenable/stage/java-shipper-application/application.properties >> $LOG_PATH 2>&1 & echo $! > $PID_PATH_NAME
        if [ $? -eq 0 ]; then
            echo "$SERVICE_NAME started ..."
        else
            echo "Failed to start $SERVICE_NAME. Rolling back to previous version..."
            rollback
        fi
    else
        echo "$SERVICE_NAME is already running ..."
    fi
}

stop_service() {
    if [ -f $PID_PATH_NAME ]; then
        PID=$(cat $PID_PATH_NAME)
        echo "$SERVICE_NAME stopping ..."
        kill $PID
        echo "$SERVICE_NAME stopped ..."
        rm $PID_PATH_NAME
    else
        echo "$SERVICE_NAME is not running ..."
    fi
}

restart_service() {
    if [ -f $PID_PATH_NAME ]; then
        PID=$(cat $PID_PATH_NAME)
        echo "$SERVICE_NAME stopping ..."
        kill $PID
        echo "$SERVICE_NAME stopped ..."
        rm $PID_PATH_NAME
    else
        echo "$SERVICE_NAME is not running ..."
    fi
    echo "$SERVICE_NAME starting ..."
    start_service
}

rollback() {
    if [ -L $PREVIOUS_SYMLINK_PATH ]; then
        echo "Rolling back to previous version..."
        # Remove the current symlink
        rm $SYMLINK_PATH
        # Create a new symlink pointing to the previous version
        ln -s $(readlink -f $PREVIOUS_SYMLINK_PATH) $SYMLINK_PATH
        start_service
    else
        echo "No previous version available for rollback."
    fi
}

case $1 in
start)
    start_service
    ;;
stop)
    stop_service
    ;;
restart)
    restart_service
    ;;
esac
