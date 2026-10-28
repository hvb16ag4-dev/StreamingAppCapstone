#!/bin/bash

echo "Free -h"
free -h

echo "nproc"
nproc

echo "dmesg -T | grep -i \"killed process\" | tail -20"
sudo dmesg -T | grep -i "killed process" | tail -20

echo "docker system df"
docker system df
