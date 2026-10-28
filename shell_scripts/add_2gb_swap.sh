#!/bin/bash

echo "*** create a temporary 2 GB swap file.This is a common practice for small build servers and CI runners.***"

echo "sudo fallocate -l 2G /swapfile"
sudo fallocate -l 2G /swapfile

echo "sudo chmod 600 /swapfile"
sudo chmod 600 /swapfile

echo "sudo mkswap /swapfile"
sudo mkswap /swapfile

echo "sudo swapon /swapfile"
sudo swapon /swapfile

echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

echo "Verify: "
echo " "

echo "free -h"
free -h

echo "swapon --show"
swapon --show
