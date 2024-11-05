#!/bin/bash

function checkDockerAndDockerComposeVersion {
    if ! [ -x "$(command -v docker)" ]; then
    echo 'Error: docker is not installed. Please install docker first!' >&2
    exit 1
    fi

    DOCKER_SERVER_VERSION=$(docker version -f "{{.Server.Version}}")
    DOCKER_SERVER_VERSION_MAJOR=$(echo "$DOCKER_SERVER_VERSION"| cut -d'.' -f 1)
    
    if [ "${DOCKER_SERVER_VERSION_MAJOR}" -ge 20 ]; then
        echo 'Docker version >= 20.10.13, using Docker Compose V2'
    else
        echo 'Docker versions < 20.x are not supported' >&2 
        exit 1
    fi

    if ! docker compose version &>/dev/null; then
        echo 'Error: docker compose is not installed. Please install docker compose.' >&2
        exit 1
    fi
    version=$(docker compose version)
    echo "Docker Compose version: $version"
    echo "---"
}

function checkIfDirectoryIsCorrect {
    current_subdir=$(basename $(pwd))
    echo "Current directory: $current_subdir"

    if [ "$current_subdir" == "qamis-lite" ] || [ "$current_subdir" == "qamis-standard" ] ; then
        echo "✓ Running in correct directory ($current_subdir)"
        return
    else
        echo "ERROR: This script must be run from either 'qamis-lite' or 'qamis-standard' subfolder."
        echo "Please cd to the appropriate directory first:"
        echo "  cd qamis-docker/qamis-lite     # For QAMIS Lite installation"
        echo "  cd qamis-docker/qamis-standard # For QAMIS Standard installation"
        exit 1
    fi
}

function start {
    echo "Starting QAMIS with default profile from $file file"
    
    # Pull latest images first
    echo "Pulling latest images..."
    docker compose --env-file "$file" pull
    
    # Start services
    echo "Starting services..."
    docker compose --env-file "$file" up -d
    
    echo "Waiting for services to initialize (this may take several minutes)..."
    sleep 30  # Initial wait for containers to start
    
    # Check core services
    MAX_ATTEMPTS=30
    ATTEMPT=1
    
    echo "Checking DHIS2..."
    until curl -f "http://localhost:8080/api/status" > /dev/null 2>&1; do
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo "ERROR: Failed to connect to DHIS2. Check logs with: docker compose --env-file $file logs dhis2"
            return 1
        fi
        echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: DHIS2 not ready, waiting..."
        sleep 10
        ATTEMPT=$((ATTEMPT + 1))
    done
    echo "✓ DHIS2 is running"
    
    ATTEMPT=1
    echo "Checking ERPNext..."
    until curl -f "http://localhost:8000/api/method/ping" > /dev/null 2>&1; do
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo "ERROR: Failed to connect to ERPNext. Check logs with: docker compose --env-file $file logs erpnext"
            return 1
        fi
        echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: ERPNext not ready, waiting..."
        sleep 10
        ATTEMPT=$((ATTEMPT + 1))
    done
    echo "✓ ERPNext is running"
    
    echo "✓ QAMIS started successfully!"
    echo
    echo "Access points:"
    echo "- DHIS2: http://localhost:8080 (admin/district)"
    echo "- ERPNext: http://localhost:8000 (Administrator/admin)"
    if [ "$current_subdir" == "qamis-standard" ]; then
        echo "- Grafana: http://localhost:3000 (admin/admin)"
        echo "- PandasAI: http://localhost:5000"
    fi
    echo
    echo "For logs, use: docker compose --env-file $file logs -f [service_name]"
}

function stop {
    echo "Stopping all QAMIS services"
    docker compose --env-file "$file" --profile standard --profile lite down
}

function sshIntoService {
    echo "Listing the running services..."
    docker compose --env-file "$file" --profile standard --profile lite ps

    echo "Enter the SERVICE name which you wish to ssh into:"
    read serviceName
    
    docker compose --env-file "$file" exec $serviceName /bin/sh
}

function showLogsOfService {
    echo "Listing the running services..."
    docker compose --env-file "$file" --profile standard --profile lite ps

    echo "Enter the SERVICE name whose logs you wish to see:"
    read serviceName
    
    docker compose --env-file "$file" logs $serviceName -f
}

function showDHIS2logs {
    echo "Opening DHIS2 Logs..."
    docker compose logs dhis2 -f 
}

function startAnalytics {
    echo "Starting analytics services (PandasAI and monitoring)..."
    docker compose --env-file "$file" --profile analytics up -d
}

function pullLatestImages {
    echo "Pulling all the images specified in the $file file..."
    docker compose --env-file "$file" pull
}

function showStatus {
    echo "Listing status of running Services"
    docker compose --env-file "$file" --profile standard --profile lite ps
}

function confirm() {
    read -p "$1 [y/n]: " response
    case $response in
        [yY][eE][sS]|[yY]) return 0 ;;
        [nN][oO]|[nN]) return 1 ;;
        *) echo "Invalid input"; return 1 ;;
    esac
}

function resetAndEraseALLVolumes {
    echo "Listing current volumes..."
    docker volume ls
    echo "---"  
    if confirm "WARNING: Are you sure you want to DELETE all QAMIS Data and Volumes??"; then
        echo "Proceeding with DELETE.... "
        docker compose --env-file "$file" --profile standard --profile lite down
        docker compose --env-file "$file" --profile standard --profile lite down -v
        
        if [ $? -eq 0 ]; then
            echo "Volumes deleted successfully."
        else
            echo "[ERROR] Command failed. Try stopping all services first."
        fi
        
        echo "Remaining volumes:"
        docker volume ls
    else
        echo "Operation cancelled"
    fi  
}

function restartService {
    echo "Listing running services that can be restarted..."
    docker compose --env-file "$file" ps

    echo "Enter the name of the SERVICE to restart:"
    read serviceName
    
    echo "Restarting SERVICE: $serviceName"
    docker compose --env-file "$file" restart $serviceName

    if confirm "Do you want to see the service logs?"; then
        docker compose --env-file "$file" logs $serviceName -f
    fi
}

checkDockerAndDockerComposeVersion
checkIfDirectoryIsCorrect

echo "Please select an option:"
echo "------------------------"
echo "1) START QAMIS services"
echo "2) STOP QAMIS services"
echo "3) LOGS: Show DHIS2 Logs"
echo "4) LOGS: Show logs of a service"
echo "5) SSH into a Container"
echo "6) START Analytics (PandasAI and Monitoring)"
echo "7) PULL latest images"
echo "8) RESET and ERASE All Volumes"
echo "9) RESTART a service"
echo "0) STATUS of all services"
echo "-------------------------"
read option

file=".env"
if ! [ "$1" == "" ]; then
    file="$1"
fi

case $option in
    1) start $file;;
    2) stop $file;;
    3) showDHIS2logs;;
    4) showLogsOfService $file;;
    5) sshIntoService $file;;
    6) startAnalytics $file;;
    7) pullLatestImages $file;;
    8) resetAndEraseALLVolumes $file;;
    9) restartService $file;;
    0) showStatus $file;;
    *) echo "Invalid option selected";;
esac
#!/bin/bash

function checkDockerAndDockerComposeVersion {
    if ! [ -x "$(command -v docker)" ]; then
    echo 'Error: docker is not installed. Please install docker first!' >&2
    exit 1
    fi

    DOCKER_SERVER_VERSION=$(docker version -f "{{.Server.Version}}")
    DOCKER_SERVER_VERSION_MAJOR=$(echo "$DOCKER_SERVER_VERSION"| cut -d'.' -f 1)
    
    if [ "${DOCKER_SERVER_VERSION_MAJOR}" -ge 20 ]; then
        echo 'Docker version >= 20.10.13, using Docker Compose V2'
    else
        echo 'Docker versions < 20.x are not supported' >&2 
        exit 1
    fi

    if ! docker compose version > /dev/null 2>&1; then
        echo 'Error: docker compose is not installed. Please install docker compose.' >&2
        exit 1
    fi
    version=$(docker compose version)
    echo "Docker Compose version: $version"
    echo "---"
}

function checkIfDirectoryIsCorrect {
    current_subdir=$(basename $(pwd))
    echo "$current_subdir"

    if [ "$current_subdir" == "qamis-lite" ] || [ "$current_subdir" == "qamis-standard" ] ; then
        return
    else
        echo "Error: This script should be run from either 'qamis-lite' or 'qamis-standard' subfolder."
        exit 1
    fi
}

function start {
    echo "Starting QAMIS with default profile from $file file"
    
    # Pull latest images first
    echo "Pulling latest images..."
    docker compose --env-file "$file" pull
    
    # Start services
    echo "Starting services..."
    docker compose --env-file "$file" up -d
    
    echo "Waiting for services to initialize (this may take several minutes)..."
    sleep 30  # Initial wait for containers to start
    
    # Check core services
    MAX_ATTEMPTS=30
    ATTEMPT=1
    
    echo "Checking DHIS2..."
    until curl -f "http://localhost:8080/api/status" > /dev/null 2>&1; do
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo "ERROR: Failed to connect to DHIS2. Check logs with: docker compose --env-file $file logs dhis2"
            return 1
        fi
        echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: DHIS2 not ready, waiting..."
        sleep 10
        ATTEMPT=$((ATTEMPT + 1))
    done
    echo "✓ DHIS2 is running"
    
    ATTEMPT=1
    echo "Checking ERPNext..."
    until curl -f "http://localhost:8000/api/method/ping" > /dev/null 2>&1; do
        if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
            echo "ERROR: Failed to connect to ERPNext. Check logs with: docker compose --env-file $file logs erpnext"
            return 1
        fi
        echo "Attempt $ATTEMPT/$MAX_ATTEMPTS: ERPNext not ready, waiting..."
        sleep 10
        ATTEMPT=$((ATTEMPT + 1))
    done
    echo "✓ ERPNext is running"
    
    echo "✓ QAMIS started successfully!"
    echo
    echo "Access points:"
    echo "- DHIS2: http://localhost:8080 (admin/district)"
    echo "- Frappe: http://localhost:8000 (Administrator/admin)"
    if [ "$current_subdir" == "qamis-standard" ]; then
        echo "- Grafana: http://localhost:3000 (admin/admin)"
        echo "- PandasAI: http://localhost:5000"
    fi
    echo
    echo "For logs, use: docker compose --env-file $file logs -f [service_name]"
}

function stop {
    echo "Stopping all QAMIS services"
    docker compose --env-file "$file" --profile standard --profile lite down
}

function sshIntoService {
    echo "Listing the running services..."
    docker compose --env-file "$file" --profile standard --profile lite ps

    echo "Enter the SERVICE name which you wish to ssh into:"
    read serviceName
    
    docker compose --env-file "$file" exec $serviceName /bin/sh
}

function showLogsOfService {
    echo "Listing the running services..."
    docker compose --env-file "$file" --profile standard --profile lite ps

    echo "Enter the SERVICE name whose logs you wish to see:"
    read serviceName
    
    docker compose --env-file "$file" logs $serviceName -f
}

function showDHIS2logs {
    echo "Opening DHIS2 Logs..."
    docker compose logs dhis2 -f 
}

function startAnalytics {
    echo "Starting analytics services (PandasAI and monitoring)..."
    docker compose --env-file "$file" --profile analytics up -d
}

function pullLatestImages {
    echo "Pulling all the images specified in the $file file..."
    docker compose --env-file "$file" pull
}

function showStatus {
    echo "Listing status of running Services"
    docker compose --env-file "$file" --profile standard --profile lite ps
}

function confirm() {
    read -p "$1 [y/n]: " response
    case $response in
        [yY][eE][sS]|[yY]) return 0 ;;
        [nN][oO]|[nN]) return 1 ;;
        *) echo "Invalid input"; return 1 ;;
    esac
}

function resetAndEraseALLVolumes {
    echo "Listing current volumes..."
    docker volume ls
    echo "---"  
    if confirm "WARNING: Are you sure you want to DELETE all QAMIS Data and Volumes??"; then
        echo "Proceeding with DELETE.... "
        docker compose --env-file "$file" --profile standard --profile lite down
        docker compose --env-file "$file" --profile standard --profile lite down -v
        
        if [ $? -eq 0 ]; then
            echo "Volumes deleted successfully."
        else
            echo "[ERROR] Command failed. Try stopping all services first."
        fi
        
        echo "Remaining volumes:"
        docker volume ls
    else
        echo "Operation cancelled"
    fi  
}

function restartService {
    echo "Listing running services that can be restarted..."
    docker compose --env-file "$file" ps

    echo "Enter the name of the SERVICE to restart:"
    read serviceName
    
    echo "Restarting SERVICE: $serviceName"
    docker compose --env-file "$file" restart $serviceName

    if confirm "Do you want to see the service logs?"; then
        docker compose --env-file "$file" logs $serviceName -f
    fi
}

checkDockerAndDockerComposeVersion
checkIfDirectoryIsCorrect

echo "Please select an option:"
echo "------------------------"
echo "1) START QAMIS services"
echo "2) STOP QAMIS services"
echo "3) LOGS: Show DHIS2 Logs"
echo "4) LOGS: Show logs of a service"
echo "5) SSH into a Container"
echo "6) START Analytics (PandasAI and Monitoring)"
echo "7) PULL latest images"
echo "8) RESET and ERASE All Volumes"
echo "9) RESTART a service"
echo "0) STATUS of all services"
echo "-------------------------"
read option

file=".env"
if ! [ "$1" == "" ]; then
    file="$1"
fi

case $option in
    1) start $file;;
    2) stop $file;;
    3) showDHIS2logs;;
    4) showLogsOfService $file;;
    5) sshIntoService $file;;
    6) startAnalytics $file;;
    7) pullLatestImages $file;;
    8) resetAndEraseALLVolumes $file;;
    9) restartService $file;;
    0) showStatus $file;;
    *) echo "Invalid option selected";;
esac
