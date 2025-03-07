# Update IP Address of NGINX configuration proxy_pass. OLD to NEW IP Address.
# NGINX Server Migration (New Public and Private IP Address)

#!/bin/bash

# Ensure the script is run with a file argument
if [ "$#" -ne 1 ]; then
    echo "Usage: sudo bash $0 <ip_mappings_file, example: ip_mappings.txt >"
    exit 1
fi

IP_FILE="$1"
CONFIG_DIR="/etc/nginx/sites.d/"
BACKUP_DIR="/home/ubuntu/nginx_sites.d_backup_$(date +%Y%m%d_%H%M%S)"

# Check if the IP mapping file exists
if [ ! -f "$IP_FILE" ]; then
    echo "Error: File '$IP_FILE' not found!"
    exit 1
fi

# Check if the backup directory exists, if not create it
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    echo "Backup directory $BACKUP_DIR created."
fi

# Backup all NGINX configuration files
echo "Backing up NGINX configuration files to $BACKUP_DIR"
cp -r $CONFIG_DIR/* $BACKUP_DIR/

# First, test connectivity to all new IP addresses
ALL_PINGS_SUCCESSFUL=true

while read -r OLD_IP NEW_IP; do
    echo "Checking connectivity to $NEW_IP..."
    
    # Ping test: 3 packets, wait max 2 seconds per packet
    if ! ping -c 3 -W 2 "$NEW_IP" > /dev/null 2>&1; then
        echo "Ping to $NEW_IP failed! Exiting."
        ALL_PINGS_SUCCESSFUL=false
        break
    fi
done < "$IP_FILE"

# If any ping failed, exit the script
if [ "$ALL_PINGS_SUCCESSFUL" = false ]; then
    echo "One or more IP addresses are unreachable. Exiting script without modifying NGINX configurations."
    exit 1
fi

# If all pings were successful, proceed with modifying the config files
echo "All new IP addresses are reachable. Proceeding with modifying NGINX configuration files."

echo "Processing IP replacements from file: $IP_FILE"

# Find all configuration files in the directory
find "$CONFIG_DIR" -type f -name "*.conf" | while read -r file; do
    CHANGED=0

    # Read each old-new IP pair and replace in the file
    while read -r OLD_IP NEW_IP; do
        if grep -q "$OLD_IP" "$file"; then
            sed -i "s/$OLD_IP/$NEW_IP/g" "$file"
            CHANGED=1
        fi
    done < "$IP_FILE"

    if [ "$CHANGED" -eq 1 ]; then
        echo "Updated: $file"
    fi
done

# Test the NGINX configuration before reloading
if sudo nginx -t; then
    echo "NGINX configuration test passed."

    echo "Reloading NGINX..."
    sudo nginx -s reload && echo "NGINX reloaded successfully." || echo "Failed to reload NGINX!"
    #sudo systemctl restart nginx && echo "NGINX restarted successfully." || echo "Failed to restart NGINX!"
else
    echo "NGINX configuration test failed. Please check the configuration files."
fi

echo "Backup of modified files stored in: $BACKUP_DIR"
