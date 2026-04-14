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

dnf module disable nodejs -y &>>"$LOG_FILE"
VALIDATE $? "disabling nodejs"

dnf module enable nodejs:20 -y  &>>"$LOG_FILE" 
dnf install nodejs -y &>>"$LOG_FILE"
VALIDATE $? "Installing nodejs"


if id roboshop &>>"$LOG_FILE"; then
  echo "User roboshop already exists... SKIPPING" &>>"$LOG_FILE"
else
  useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>"$LOG_FILE"
  VALIDATE $? "Creating system user"
fi

mkdir -p /app
VALIDATE $? "creating app dir"  

curl -o /tmp/user.zip https://roboshop-artifacts.s3.amazonaws.com/user-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading application code"
rm -rf /app/*
cd /app
unzip /tmp/user.zip  &>>$LOG_FILE
VALIDATE $? "Unziping user" &>>$LOG_FILE

cd /app
npm install &>>$LOG_FILE
VALIDATE $? "Installing nodejs dependencies"    

chown -R roboshop:roboshop /app
VALIDATE $? "Changing ownership of app directory"   

cp $SCRIPT_DIR/user.service /etc/systemd/system/user.service &>>$LOG_FILE
VALIDATE $? "Copying user systemd service file"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Reloading systemd"

echo -e "Script exection completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE



 

