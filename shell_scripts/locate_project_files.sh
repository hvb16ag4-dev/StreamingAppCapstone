#!/bin/bash

# 1. Capture the directory argument. Default to "." if nothing is passed.
TARGET_DIR="${1:-.}"

# 2. Check if the provided directory actually exists before running find
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

echo -e "\n--- Project Files ---"
# Locates the backend Dockerfile and falls back to a warning message if missing
echo "Backend Dockerfile: $(find "$TARGET_DIR"/backend -maxdepth 2 -name Dockerfile 2>/dev/null || echo 'Not Found')"

echo "Backend package.json: $(find "$TARGET_DIR"/backend -maxdepth 2 -name package.json 2>/dev/null || echo 'Not Found')"

echo "Backend Requirements.txt: $(find "$TARGET_DIR"/backend -maxdepth 2 -name requirements.txt 2>/dev/null || echo 'Not Found')"

echo "Backend pom.xml: $(find "$TARGET_DIR"/backend -maxdepth 2 -name pom.xml 2>/dev/null || echo 'Not Found')"

echo "Backend go.mod: $(find "$TARGET_DIR"/backend -maxdepth 2 -name go.mod 2>/dev/null || echo 'Not Found')"

echo "Frontend Dockerfile: $(find "$TARGET_DIR"/frontend -maxdepth 2 -name Dockerfile 2>/dev/null || echo 'Not Found')"

echo "Frontend package.json: $(find "$TARGET_DIR"/frontend -maxdepth 2 -name package.json 2>/dev/null || echo 'Not Found')"

