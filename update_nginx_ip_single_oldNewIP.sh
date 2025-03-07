#!/bin/bash

# Ensure the script is run with two arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: bash $0 <OLD_IP> <NEW_IP>"
    exit 1
fi

OLD_IP="$1"
NEW_IP="$2"
CONFIG_DIR="/etc/nginx/sites.d/"
BACKUP_DIR="/home/ubuntu/nginx_sites.d_backup_$1to$2_$(date +%Y%m%d_%H%M%S)"

# Check if the backup directory exists, if not create it
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    echo "Backup directory $BACKUP_DIR created."
fi

# Backup all NGINX configuration files
echo "Backing up NGINX configuration files to $BACKUP_DIR"
cp -r $CONFIG_DIR/* $BACKUP_DIR/

echo "Checking connectivity to $NEW_IP..."
if ! ping -c 3 -W 2 "$NEW_IP" > /dev/null 2>&1; then
    echo "Ping to $NEW_IP failed! Exiting."
    exit 1
else
    # If all pings were successful, proceed with modifying the config files
    echo "New IP addresses is reachable. Proceeding with modifying NGINX configuration files."
fi

# Find and replace IP addresses in all configuration files
echo "Searching for '$OLD_IP' in $CONFIG_DIR and replacing with '$NEW_IP'..."

# Iterate over each .conf file in CONFIG_DIR
find "$CONFIG_DIR" -type f -name "*.conf" | while IFS= read -r file; do
    if grep -q "$OLD_IP" "$file"; then
        sed -i "s/$OLD_IP/$NEW_IP/g" "$file"
        echo "Updated: $file"
    fi
done

if sudo nginx -t; then
    echo "NGINX configuration test passed."
    echo "Reloading NGINX..."
    sudo nginx -s reload && echo "NGINX reloaded successfully." || echo "Failed to reload NGINX!"
    #sudo systemctl restart nginx && echo "NGINX restarted successfully." || echo "Failed to restart NGINX!"
else
    echo "NGINX configuration test failed. Please check the configuration files."
fi

# For testing
#sudo rm -rf /etc/nginx/ && sudo cp -r etc/nginx/ /etc/ && sudo chown -R ubuntu: /etc/nginx/ && ls -la /etc/nginx/
