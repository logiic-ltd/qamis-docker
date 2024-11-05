#!/bin/bash

if [ -z "$1" ]; then
    echo "Please provide backup directory path"
    exit 1
fi

BACKUP_DIR=$1

# Restore DHIS2
echo "Restoring DHIS2 database..."
docker compose exec -T dhis2db psql -U dhis < "$BACKUP_DIR/dhis2.sql"

# Restore ERPNext
echo "Restoring ERPNext database and files..."
docker compose exec -T erpnext bench --site site1.local restore "$BACKUP_DIR/site1.local.sql"

# Restore QAMIS integration database
echo "Restoring QAMIS integration database..."
docker compose exec -T qamisdb psql -U qamis < "$BACKUP_DIR/qamis.sql"

echo "Restore completed successfully"
