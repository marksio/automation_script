#!/bin/bash

# MongoDB info
HOST="127.0.0.1"        # MongoDB IP
PORT="27017"            # MongoDB port
DB_USERNAME="xxx"     # MongoDB User
DB_PASSWORD="xxx" #Mongo DB Password
BACKUP_DIR="/data/mongodb-backup"  # Replace with your desired backup directory

# Timestamp
TIMESTAMP=$(date +%Y%m%d)


# Backup MongoDB without acquiring a global write lock
sudo mongodump --host $HOST --port $PORT --username $DB_USERNAME --password $DB_PASSWORD --authenticationDatabase admin --out $BACKUP_DIR/mongo_$TIMESTAMP --forceTableScan

# Check if the backup was successful
if [ $? -eq 0 ]; then
    echo "Backup completed successfully. Backup directory: $BACKUP_DIR/$TIMESTAMP"

    # Zip the backup directory
    sudo zip -r $BACKUP_DIR/mongo_${TIMESTAMP}.zip $BACKUP_DIR/mongo_$TIMESTAMP

    # Transfer zipped backups to another server using rsync
    BACKUP_SERVER_USER="xxx"   # Replace with your backup server username
    BACKUP_SERVER_IP="x.x.x.x"       # Replace with your backup server IP
    BACKUP_SERVER_PATH="/data/mongodb-backup"  # Replace with your backup directory on the backup server

    # rsync the zipped backups to the backup server
    sudo rsync -avxP --delete "$BACKUP_DIR/mongo_${TIMESTAMP}.zip" "$BACKUP_SERVER_USER@$BACKUP_SERVER_IP:$BACKUP_SERVER_PATH"

    # Remove the local backup zip file
    sudo rm -rf "$BACKUP_DIR/mongo_${TIMESTAMP}"
    sudo rm -rf "$BACKUP_DIR/mongo_${TIMESTAMP}.zip"

    echo "Zipped backups transferred to the backup server, and local backup zip file removed."
else
    echo "Backup failed. Please check the error messages."
fi
