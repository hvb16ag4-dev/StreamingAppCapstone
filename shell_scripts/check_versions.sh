#!/bin/bash

echo "--- Operating System Info ---"
echo "OS Name: $(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || echo 'Unknown')"
echo "OS Version: $(grep '^VERSION_ID=' /etc/os-release | cut -d= -f2 | tr -d '"' 2>/dev/null || echo 'Unknown')"

echo -e "\n--- System Storage ---"
# Displays total, used, and available space on the root filesystem in human-readable format
echo "Root Disk Usage:"
df -h / | awk 'NR==2 {print "  Total: " $2 ", Used: " $3 ", Available: " $4 " (" $5 ") "}'

echo -e "\n--- Installed Tools Versions ---"

# 1. Git
echo "Git: $(git --version 2>/dev/null || echo 'Not Installed')"

# 2. Node.js
echo "Node.js: $(node -v 2>/dev/null || echo 'Not Installed')"

# 3. Python 3
echo "Python: $(python3 --version 2>/dev/null || echo 'Not Installed')"

# 4. Docker
echo "Docker: $(docker --version | head -n 1 2>/dev/null || echo 'Not Installed')"

# 5. Docker Compose
# Checks both the modern 'docker compose' plugin and the legacy 'docker-compose' standalone binary
if docker compose version &>/dev/null; then
    echo "Docker Compose: $(docker compose version | head -n 1)"
elif docker-compose --version &>/dev/null; then
    echo "Docker Compose: $(docker-compose --version | head -n 1)"
else
    echo "Docker Compose: Not Installed"
fi

# 6. Java
echo "Java: $(java -version 2>&1 | head -n 1 || echo 'Not Installed')"

# 7. AWS CLI
echo "AWS CLI: $(aws --version 2>&1 | head -n 1 || echo 'Not Installed')"

# 8. Bash itself
echo "Bash: $(echo $BASH_VERSION)"

