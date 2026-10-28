#!/bin/bash

echo "Clean free some disk space and remove unused build cache."

echo "docker builder prune -af"
docker builder prune -af

echo "docker image prune -af"
docker image prune -af
