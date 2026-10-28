#!/bin/bash

sudo apt update

sudo apt install -y docker.io docker-compose-v2

sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker $USER

echo "Now log out of the SSH session and log back in (or run newgrp docker) so your user picks up the Docker group membership."

