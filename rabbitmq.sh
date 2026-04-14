#!/bin/bash

USERID=$(id -u)
R="\e[31m"; G="\e[32m"; Y="\e[33m"; N="\e[0m"

LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$(pwd)

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

# Root check
if [ $USERID -ne 0 ]; then
    echo -e "$R ERROR: Run with root access $N" | tee -a $LOG_FILE
    exit 1
fi

# Validate function
VALIDATE() {
    if [ $1 -eq 0 ]; then
        echo -e "$2 ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

# Copy repo file
cp $SCRIPT_DIR/rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo &>>$LOG_FILE
VALIDATE $? "Copying rabbitmq repo"

# Install RabbitMQ (idempotent)
dnf list installed rabbitmq-server &>>$LOG_FILE
if [ $? -ne 0 ]; then
    dnf install rabbitmq-server -y &>>$LOG_FILE
    VALIDATE $? "Installing rabbitmq server"
else
    echo "RabbitMQ already installed... SKIPPING" | tee -a $LOG_FILE
fi

# Enable & start service
systemctl enable rabbitmq-server &>>$LOG_FILE
VALIDATE $? "Enabling rabbitmq server"

systemctl start rabbitmq-server &>>$LOG_FILE
VALIDATE $? "Starting rabbitmq server"

# Create user (idempotent)
rabbitmqctl list_users | grep roboshop &>>$LOG_FILE
if [ $? -ne 0 ]; then
    rabbitmqctl add_user roboshop roboshop123 &>>$LOG_FILE
    VALIDATE $? "Creating rabbitmq user"
else
    echo "RabbitMQ user already exists... SKIPPING" | tee -a $LOG_FILE
fi

# Set permissions (safe to run multiple times)
rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>>$LOG_FILE
VALIDATE $? "Setting permissions"