#!/bin/bash

set -e  # Exit on any error

check_service() {
    local service=$1
    local url=$2
    local max_attempts=${3:-30}
    local attempt=1

    echo "Checking $service..."
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            echo "✓ $service is running"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts: $service not ready, waiting..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: Failed to connect to $service after $max_attempts attempts"
    return 1
}

# Check core services
check_service "DHIS2" "http://dhis2:8080/api/status"
check_service "ERPNext" "http://erpnext:8000/api/method/erpnext.ping"
check_service "Nginx" "http://nginx/health"

# Check optional services based on deployment type
if [ "$DEPLOYMENT_TYPE" = "standard" ]; then
    check_service "PandasAI" "http://pandasai:5000/health"
    check_service "Grafana" "http://grafana:3000/api/health"
fi

echo "✓ All services are running"
