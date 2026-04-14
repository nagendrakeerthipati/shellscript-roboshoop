#!/bin/bash
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD 
mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE 

# check the user has root priveleges or not
if [ $USERID -ne 0 ]; then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1 #give other than 0 upto 127
else
    echo "You are running with root access" | tee -a $LOG_FILE
fi  

# validate functions takes input as exit status, what command they tried to install
VALIDATE() {
    if [ $1 -eq 0 ]; then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}   

dnf install golang -y &>>$LOG_FILE
VALIDATE $? "Installing golang"


mkdir -p /app &>>$LOG_FILE
VALIDATE $? "creating app dir"

curl -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading application code"
rm -rf /app/*
cd /app

unzip /tmp/dispatch.zip  &>>$LOG_FILE
VALIDATE $? "Unziping dispatch" &>>$LOG_FILE

cd /app
if [ ! -f "/app/dispatch" ]; then
    go mod init dispatch &>>$LOG_FILE
    VALIDATE $? "Initializing go module"

    go get &>>$LOG_FILE
    VALIDATE $? "Downloading dependencies"

    go build &>>$LOG_FILE
    VALIDATE $? "Building dispatch"
else
    echo "Dispatch already built... SKIPPING" | tee -a $LOG_FILE
fi

cp $SCRIPT_DIR/dispatch.service /etc/systemd/system/dispatch.service &>>$LOG_FILE
VALIDATE $? "Copying systemd service file"



systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Reloading systemd daemon"

systemctl enable dispatch &>>$LOG_FILE
VALIDATE $? "Enabling dispatch service"

systemctl start dispatch  &>>$LOG_FILE
VALIDATE $? "Starting dispatch service" 




