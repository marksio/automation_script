#!/bin/bash

# MySQL Config Detail
DB_HOST="localhost" # MySQL IP
DB_PORT="3306"      # MySQL Port
DB_USER="xxx"      # MySQL Username
DB_PASSWORD="xxx" # MySQL Password
DB_NAME=""  # MySQL DB Name

# Backup Directory
BASE_BACKUP_DIR="/data/mysql-backup"

# Sub-Directory with DateTime
TIMESTAMP=$(date +%Y%m%d)
FULL_BACKUP_DIR="$BASE_BACKUP_DIR/mysql_full_backup"
INCREMENTAL_BACKUP_DIR="$BASE_BACKUP_DIR/mysql_incremental_backup/$TIMESTAMP"

# Create the full backup directory and incremental backup directory if they do not exist
sudo mkdir -p $FULL_BACKUP_DIR
sudo mkdir -p $INCREMENTAL_BACKUP_DIR

# Get the current date and day of the week
DAY_OF_WEEK=$(date +%u)
# Full preparation time
NOW_DAY=3

# Backup Type
BACKUP_TYPE=""
# Zip File Name
ZIP_NAME=""

# Full backup (every Monday)
if [ $DAY_OF_WEEK -eq $NOW_DAY ]; then
    sudo xtrabackup --backup --target-dir=$FULL_BACKUP_DIR/$TIMESTAMP --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --databases="$DB_NAME" --no-lock
    BACKUP_TYPE="Full"
    ZIP_NAME="mysql_full_backup_crawler_$TIMESTAMP.zip"
else
    # Incremental backup (Tuesday to Sunday)
    LATEST_FULL_BACKUP=$(ls -td $FULL_BACKUP_DIR/* | head -n 1)
    sudo xtrabackup --backup --target-dir=$INCREMENTAL_BACKUP_DIR --host=$DB_HOST --port=$DB_PORT --user=$DB_USER --password=$DB_PASSWORD --databases="$DB_NAME" --no-lock --incremental-basedir=$LATEST_FULL_BACKUP
    BACKUP_TYPE="Incremental"
    ZIP_NAME="mysql_incremental_backup_crawler_$TIMESTAMP.zip"
fi

# Check if the backup was successful
if [ $? -eq 0 ]; then
    echo "$BACKUP_TYPE Backup completed successfully."

    # Pack backup files as ZIP
    ZIP_FILE="$BASE_BACKUP_DIR/$ZIP_NAME"

    if [ $DAY_OF_WEEK -eq $NOW_DAY ]; then
        # ZIP Full backup directory
        sudo zip -r $ZIP_FILE $FULL_BACKUP_DIR
    else
        # ZIP Incremental backup directory
        sudo zip -r $ZIP_FILE $INCREMENTAL_BACKUP_DIR
    fi

    # Transfer backups to another server using rsync
    BACKUP_SERVER_USER="xxx"  # Replace with your backup server username
    BACKUP_SERVER_IP="x.x.x.x"  # Replace with your backup server IP
    BACKUP_SERVER_PATH="/data/mysql-backup"   # Replace with your backup directory on the backup server

    # rsync the ZIP file to the backup server
    sudo rsync -avxP --delete "$ZIP_FILE" "$BACKUP_SERVER_USER@$BACKUP_SERVER_IP:$BACKUP_SERVER_PATH"

    echo "Backup ZIP file transferred to the backup server."
else
    echo "$BACKUP_TYPE Backup failed. Please check the error messages."
    exit 1
fi
