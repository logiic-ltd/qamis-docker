#!/bin/bash

# Source utility functions
source "$(dirname "$0")/backup_utils.sh"

# Create backup directory with timestamp
BACKUP_DIR="/backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup DHIS2
log_info "Backing up DHIS2..."
backup_db "postgres" "dhis2" "dhis" "dhis" "dhis2db" "$BACKUP_DIR/dhis2.sql"
backup_container_file_system "dhis2" "/opt/dhis2" "$BACKUP_DIR/dhis2_files"

# Backup ERPNext
log_info "Backing up ERPNext..."
docker compose exec -T erpnext bench --site site1.local backup --with-files
# Move ERPNext backups to our backup directory
docker compose cp erpnext:/home/erpnext/erpnext-bench/sites/site1.local/private/backups/ "$BACKUP_DIR/erpnext_backup"

# Backup QAMIS integration
log_info "Backing up QAMIS integration..."
backup_db "postgres" "qamis" "qamis" "qamis" "qamisdb" "$BACKUP_DIR/qamis.sql"

# Check if running standard profile
if [ "$(docker compose ps -q pandasai)" != "" ]; then
    log_info "Backing up analytics data..."
    backup_container_file_system "pandasai" "/data" "$BACKUP_DIR/pandasai_data"
    backup_container_file_system "grafana" "/var/lib/grafana" "$BACKUP_DIR/grafana_data"
fi

# Verify backups
log_info "Verifying backups..."
verify_backup "$BACKUP_DIR/dhis2.sql.gz"
verify_backup "$BACKUP_DIR/dhis2_files/data.tar.gz"
verify_backup "$BACKUP_DIR/erpnext_backup/database.sql.gz"
verify_backup "$BACKUP_DIR/qamis.sql.gz"

if [ -f "$BACKUP_DIR/pandasai_data/data.tar.gz" ]; then
    verify_backup "$BACKUP_DIR/pandasai_data/data.tar.gz"
    verify_backup "$BACKUP_DIR/grafana_data/data.tar.gz"
fi

log_info "Backup completed successfully at $BACKUP_DIR"
