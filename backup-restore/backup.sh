#!/bin/bash

BACKUP_DIR="/backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p $BACKUP_DIR

# Backup DHIS2
echo "Backing up DHIS2 database..."
docker compose exec -T dhis2db pg_dump -U dhis > "$BACKUP_DIR/dhis2.sql"

# Backup Frappe
echo "Backing up Frappe database and files..."
docker compose exec -T frappe bench --site site1.local backup --with-files

# Backup QAMIS integration database
echo "Backing up QAMIS integration database..."
docker compose exec -T qamisdb pg_dump -U qamis > "$BACKUP_DIR/qamis.sql"

echo "Backup completed successfully"
