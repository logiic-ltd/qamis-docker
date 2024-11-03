#!/bin/bash

set -e  # Exit on any error

echo "Starting DHIS2 initialization..."
echo "Checking prerequisites..."

# Validate environment variables
if [ -z "$DHIS2_ADMIN_USER" ] || [ -z "$DHIS2_ADMIN_PASSWORD" ]; then
    echo "ERROR: DHIS2_ADMIN_USER and DHIS2_ADMIN_PASSWORD must be set"
    exit 1
fi

# Check for metadata file
if [ ! -f /metadata/qamis-metadata.json ]; then
    echo "ERROR: Required metadata file not found at /metadata/qamis-metadata.json"
    exit 1
fi

MAX_ATTEMPTS=30
ATTEMPT=1

echo "Waiting for DHIS2 to start (this may take several minutes)..."
until curl -f "http://dhis2:8080/api/status" > /dev/null 2>&1; do
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "ERROR: Failed to connect to DHIS2 after $MAX_ATTEMPTS attempts"
        exit 1
    fi
    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: DHIS2 not ready, waiting..."
    sleep 10
    ATTEMPT=$((ATTEMPT + 1))
done

echo "✓ DHIS2 is running"
echo "Checking database initialization..."

# Verify database is properly initialized
DB_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
    -u "$DHIS2_ADMIN_USER:$DHIS2_ADMIN_PASSWORD" \
    "http://dhis2:8080/api/system/info")

if [ "$DB_CHECK" -eq 401 ]; then
    echo "ERROR: Authentication failed. Please check DHIS2 credentials"
    exit 1
elif [ "$DB_CHECK" -ne 200 ]; then
    echo "ERROR: DHIS2 system check failed with code $DB_CHECK"
    exit 1
fi

echo "✓ Database initialized"
echo "Importing DHIS2 metadata..."

RESPONSE=$(curl -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
     -u "$DHIS2_ADMIN_USER:$DHIS2_ADMIN_PASSWORD" \
     -d @/metadata/qamis-metadata.json \
     "http://dhis2:8080/api/metadata")

HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "✓ DHIS2 metadata imported successfully"
else
    echo "ERROR: Failed to import DHIS2 metadata. Response: $BODY"
    exit 1
fi

echo "✓ DHIS2 initialization complete"
