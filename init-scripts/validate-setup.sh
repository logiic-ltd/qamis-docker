#!/bin/bash

# Required directories
DIRS=(
    "./dhis2-config"
    "./nginx/conf.d"
    "./nginx/certs"
    "./erpnext-apps"
    "./prometheus"
    "./grafana/provisioning"
    "./grafana/dashboards"
)

# Required files
FILES=(
    "./dhis2-config/dhis.conf"
    "./nginx/conf.d/default.conf"
    "./nginx/.htpasswd"
    "./prometheus/prometheus.yml"
)

# Check and create directories
for dir in "${DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi
done

# Check required files exist
for file in "${FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Required file missing: $file"
        exit 1
    fi
done

# Ensure scripts are executable
chmod +x init-scripts/*.sh

# Validate environment files
if [ ! -f ".env" ]; then
    echo "WARNING: No .env file found, using defaults"
fi

echo "✓ Setup validation complete"
