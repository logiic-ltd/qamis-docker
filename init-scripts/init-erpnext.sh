#!/bin/bash

set -e  # Exit on any error

echo "Starting ERPNext initialization..."

# Validate environment variables
if [ -z "$FRAPPE_ADMIN_PASSWORD" ]; then
    echo "ERROR: FRAPPE_ADMIN_PASSWORD must be set"
    exit 1
fi

MAX_ATTEMPTS=30
ATTEMPT=1

echo "Waiting for ERPNext to start (this may take several minutes)..."
until curl -f "http://erpnext:8000/api/method/ping" > /dev/null 2>&1; do
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "ERROR: Failed to connect to Frappe after $MAX_ATTEMPTS attempts"
        exit 1
    fi
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: Frappe not ready, waiting..."
    sleep 10
    ATTEMPT=$((ATTEMPT + 1))
done

echo "✓ Frappe is running"
echo "Checking database initialization..."

# Verify database connection
bench --site site1.local doctor > /dev/null 2>&1 || {
    echo "ERROR: Database check failed"
    exit 1
}

echo "✓ Database initialized"
echo "Installing required Frappe apps..."

# Function to install app with retries
install_app() {
    local app_name=$1
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if bench --site site1.local install-app "$app_name"; then
            echo "✓ Successfully installed $app_name"
            return 0
        else
            retry=$((retry + 1))
            if [ $retry -eq $max_retries ]; then
                echo "ERROR: Failed to install $app_name after $max_retries attempts"
                exit 1
            fi
            echo "Retry $retry/$max_retries: Installing $app_name..."
            sleep 5
        fi
    done
}

# Install ERPNext first as it's a dependency
install_app "erpnext"

# Install custom apps
install_app "accreditation-management"
install_app "qamis-inspection-management"

# Verify apps are properly installed
bench --site site1.local list-apps | grep -q "erpnext" || {
    echo "ERROR: erpnext not properly installed"
    exit 1
}

bench --site site1.local list-apps | grep -q "accreditation-management" || {
    echo "ERROR: accreditation-management not properly installed"
    exit 1
}

bench --site site1.local list-apps | grep -q "qamis-inspection-management" || {
    echo "ERROR: qamis-inspection-management not properly installed"
    exit 1
}

echo "✓ Apps installed successfully"
echo "✓ Frappe initialization complete"
#!/bin/bash

set -e  # Exit on any error

echo "Starting ERPNext initialization..."

# Create required directories
mkdir -p /home/erpnext/sites
mkdir -p /home/erpnext/apps

# Wait for database to be ready
MAX_ATTEMPTS=30
ATTEMPT=1

echo "Waiting for MariaDB to start..."
until mysqladmin ping -h"$DB_HOST" -u"root" -p"$MYSQL_ROOT_PASSWORD" --silent; do
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "ERROR: MariaDB not ready after $MAX_ATTEMPTS attempts"
        exit 1
    fi
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: MariaDB not ready, waiting..."
    sleep 10
    ATTEMPT=$((ATTEMPT + 1))
done

echo "✓ MariaDB is running"

# Initialize site if it doesn't exist
if [ ! -d "/home/erpnext/sites/site1.local" ]; then
    echo "Creating new ERPNext site..."
    bench new-site site1.local \
        --mariadb-root-password "$MYSQL_ROOT_PASSWORD" \
        --admin-password admin \
        --no-mariadb-socket
    
    echo "Installing ERPNext application..."
    bench --site site1.local install-app erpnext
    
    # Install additional apps if specified
    if [ ! -z "$INSTALL_APPS" ]; then
        echo "Installing additional apps..."
        echo "$INSTALL_APPS" | while IFS=, read -r app_name app_url; do
            if [ ! -z "$app_name" ]; then
                echo "Installing $app_name from $app_url"
                bench get-app "$app_name" "$app_url"
                bench --site site1.local install-app "$app_name"
            fi
        done
    fi
fi

echo "✓ ERPNext initialization complete"
