# #!/bin/bash
# USERID=$(id -u)
# R="\e[31m"
# G="\e[32m"
# Y="\e[33m"
# N="\e[0m"
# LOGS_FOLDER="/var/log/roboshop-logs"
# SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
# LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
# SCRIPT_DIR=$PWD 
# mkdir -p $LOGS_FOLDER
# echo "Script started executing at: $(date)" | tee -a $LOG_FILE 

# # check the user has root priveleges or not
# if [ $USERID -ne 0 ]; then
#     echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
#     exit 1 #give other than 0 upto 127
# else
#     echo "You are running with root access" | tee -a $LOG_FILE
# fi  

# # validate functions takes input as exit status, what command they tried to install
# VALIDATE() {
#     if [ $1 -eq 0 ]; then
#         echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
#     else
#         echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
#         exit 1
#     fi
# }   

# dnf install golang -y &>>$LOG_FILE
# VALIDATE $? "Installing golang"


# mkdir -p /app &>>$LOG_FILE
# VALIDATE $? "creating app dir"

# curl -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip &>>$LOG_FILE
# VALIDATE $? "Downloading application code"
# rm -rf /app/*
# cd /app

# unzip /tmp/dispatch.zip  &>>$LOG_FILE
# VALIDATE $? "Unziping dispatch" &>>$LOG_FILE

# cd /app
# if [ ! -f "/app/dispatch" ]; then
#     go mod init dispatch &>>$LOG_FILE
#     VALIDATE $? "Initializing go module"

#     go get &>>$LOG_FILE
#     VALIDATE $? "Downloading dependencies"

#     go build &>>$LOG_FILE
#     VALIDATE $? "Building dispatch"
# else
#     echo "Dispatch already built... SKIPPING" | tee -a $LOG_FILE
# fi

# cp $SCRIPT_DIR/dispatch.service /etc/systemd/system/dispatch.service &>>$LOG_FILE
# VALIDATE $? "Copying systemd service file"



# systemctl daemon-reload &>>$LOG_FILE
# VALIDATE $? "Reloading systemd daemon"

# systemctl enable dispatch &>>$LOG_FILE
# VALIDATE $? "Enabling dispatch service"

# systemctl start dispatch  &>>$LOG_FILE
# VALIDATE $? "Starting dispatch service" 

#!/bin/bash

set -e  # exit on error

USERID=$(id -u)
R="\e[31m"; G="\e[32m"; Y="\e[33m"; N="\e[0m"

LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(basename "$0" .sh)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$LOGS_FOLDER"
echo "Script started executing at: $(date)" | tee -a "$LOG_FILE"

# Root check
if [ "$USERID" -ne 0 ]; then
    echo -e "$R ERROR: Run with root access $N" | tee -a "$LOG_FILE"
    exit 1
fi

# Validation helper
VALIDATE() {
    if [ "$1" -eq 0 ]; then
        echo -e "$2 ... $G SUCCESS $N" | tee -a "$LOG_FILE"
    else
        echo -e "$2 ... $R FAILURE $N" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Install golang (idempotent)
if ! dnf list installed golang &>>"$LOG_FILE"; then
    dnf install golang -y &>>"$LOG_FILE"
    VALIDATE $? "Installing golang"
else
    echo "Golang already installed... SKIPPING" | tee -a "$LOG_FILE"
fi

# Ensure roboshop user
if ! id roboshop &>>"$LOG_FILE"; then
    useradd roboshop &>>"$LOG_FILE"
    VALIDATE $? "Creating roboshop user"
else
    echo "roboshop user exists... SKIPPING" | tee -a "$LOG_FILE"
fi

# Prepare app dir
mkdir -p /app &>>"$LOG_FILE"
VALIDATE $? "Creating app directory"

# Download code
curl -L -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip &>>"$LOG_FILE"
VALIDATE $? "Downloading application code"

# Clean and extract
rm -rf /app/*
cd /app
unzip -o /tmp/dispatch.zip &>>"$LOG_FILE"
VALIDATE $? "Unzipping dispatch"

# Build only if binary not present
if [ ! -f /app/dispatch ]; then
    go mod init dispatch &>>"$LOG_FILE"
    VALIDATE $? "Init go module"

    go get &>>"$LOG_FILE"
    VALIDATE $? "Get dependencies"

    go build &>>"$LOG_FILE"
    VALIDATE $? "Build dispatch"
else
    echo "Binary already exists... SKIPPING build" | tee -a "$LOG_FILE"
fi

# --- SYSTEMD (correct order) ---

# Unmask first (safe)
systemctl unmask dispatch &>>"$LOG_FILE" || true

# Copy service file
cp "$SCRIPT_DIR/dispatch.service" /etc/systemd/system/dispatch.service &>>"$LOG_FILE"
VALIDATE $? "Copying service file"

# Reload daemon
systemctl daemon-reload &>>"$LOG_FILE"
VALIDATE $? "Reloading systemd"

# Enable service
systemctl enable dispatch &>>"$LOG_FILE"
VALIDATE $? "Enabling service"

# Restart service (idempotent)
systemctl restart dispatch &>>"$LOG_FILE"
VALIDATE $? "Starting service"