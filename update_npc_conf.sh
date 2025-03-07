# Use for updating Nps Server IP Address

#!/bin/bash

# Define variables
PRIVATE_KEY="$HOME/Desktop/MarkPrivateKey"
USERNAME="ubuntu"
CONFIG_PATH="/opt/nps-client/conf/npc.conf"
NEW_NPS_IP="xx.x.x.xx"  # <-- Change this to your new NPS server IP
TELNET_PORT=xxxx
BACKUP_SUFFIX=".backup_$(date +%Y%m%d_%H%M%S)"

# List of servers (IP:PORT format)
SERVERS=(
    "10.xx.xx.xx:22"
)

echo "Starting NPC configuration update on multiple servers..."

# Loop through each server
for SERVER in "${SERVERS[@]}"; do
    HOST=$(echo "$SERVER" | cut -d':' -f1)
    PORT=$(echo "$SERVER" | cut -d':' -f2)

    echo "🔄 Checking connectivity to $HOST on port $PORT..."
    nc -z -w 3 "$HOST" "$PORT"
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: Unable to connect to $HOST on port $PORT. Skipping..."
        continue
    fi

    echo "🔄 Pinging new NPS Server IP ($NEW_NPS_IP) from $HOST..."
    ssh -i "$PRIVATE_KEY" -p "$PORT" -o StrictHostKeyChecking=no "$USERNAME@$HOST" "ping -c 3 -W 2 $NEW_NPS_IP"
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: $HOST cannot reach $NEW_NPS_IP. Skipping..."
    fi

    echo "🔄 Telnet test from $HOST to $NEW_NPS_IP:$TELNET_PORT..."
    ssh -i "$PRIVATE_KEY" -p "$PORT" -o StrictHostKeyChecking=no "$USERNAME@$HOST" "nc -z -w 3 $NEW_NPS_IP $TELNET_PORT"
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: Telnet from $HOST to $NEW_NPS_IP:$TELNET_PORT failed. Skipping..."
        continue
    fi

    echo "✅ Connecting to $HOST and modifying $CONFIG_PATH..."

    # Run commands via SSH
    ssh -i "$PRIVATE_KEY" -p "$PORT" -o StrictHostKeyChecking=no "$USERNAME@$HOST" <<EOF
        echo "✅ Connected to $HOST. Modifying $CONFIG_PATH..."

        # Backup the current npc.conf file
        sudo cp "$CONFIG_PATH" "$CONFIG_PATH$BACKUP_SUFFIX"

        # Replace old NPS server IP with the new one (including Telnet port)
        sudo sed -i "s/^server_addr=.*/server_addr=$NEW_NPS_IP:$TELNET_PORT/" "$CONFIG_PATH"

        # Restart Npc service
        echo "🔄 Restarting Npc service..."
        sudo systemctl restart Npc

        echo "🔄 Wait for 1 Second..."
        # Wait for 1 second
        sleep 1

        # Verify Npc service status
        echo "🔍 Checking Npc service status..."
        sudo systemctl status Npc --no-pager | head -n 20
EOF

    echo "✅ Configuration updated successfully on $HOST!"
done

echo "🎉 All servers processed."
