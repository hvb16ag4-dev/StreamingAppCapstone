#!/bin/bash


cd /tmp

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip

sudo apt update
sudo apt install -y unzip

unzip awscliv2.zip

sudo ./aws/install

echo "----- Verify AWS -----"

aws --version


