#!/bin/bash

#install MongoDB
dnf install mongodb-org -y 

if [ $? -ne 0]

# Start & Enable MongoDB Service
systemctl start mongod
systemctl status mongod

#Update listen address from 127.0.0.1 to 0.0.0.0 in /etc/mongod.conf

sed -i 's/12.0.0.1/0.0.0.0/g' /etc/mongod.conf

#restart the service 
systemctl restart mongod