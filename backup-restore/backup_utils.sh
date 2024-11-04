#!/bin/bash

function log_error() {
    local message=$1
    echo -e "\033[31mERROR - ${message}\033[0m"
}

function log_warning() {
    local message=$1
    echo -e "\033[33mWARN - ${message}\033[0m"
}

function log_info() {
    local message=$1
    echo "INFO - ${message}"
}

function is_compose_container_running() {
    local service_name=$1
    if [ -z $(docker compose ps -q $service_name) ] || [ -z $(docker ps -q --no-trunc | grep $(docker compose ps -q $service_name)) ]; then
        echo 0
    else
        echo 1
    fi
}

function is_compose_container_present() {
    local service_name=$1
    if [ -z $(docker compose ps -a -q $service_name) ]; then
        echo 0
    else
        echo 1
    fi
}

function is_directory_exists() {
    if [[ -d $1 ]]; then
        return 0
    else
        return 1
    fi
}

function is_directory_empty() {
    if [[ -z "$(ls -A $1)" ]]; then
        return 0
    else
        return 1
    fi
}

function backup_db() {
    local db_type=$1
    local db_name=$2
    local db_username=$3
    local db_password=$4
    local db_service_name=$5
    local backup_file_path=$6
    
    if [[ $(is_compose_container_running $db_service_name) -eq 1 ]]; then
        # Create temp file for backup
        local temp_backup="/tmp/${db_name}_$(date +%s).sql"
        
        if [[ $db_type == "postgres" ]]; then
            docker compose exec $db_service_name pg_dump -U $db_username -d $db_name -F p -b -v >"$temp_backup"
            local exit_code=$?
        elif [[ $db_type == "mysql" ]]; then
            docker compose exec $db_service_name mysqldump -u $db_username --password=$db_password --routines --triggers --events $db_name --no-tablespaces >"$temp_backup"
            local exit_code=$?
        else
            log_error "Unsupported database type: $db_type"
            return 1
        fi

        if [ $exit_code -eq 0 ]; then
            # Compress backup
            gzip -c "$temp_backup" > "${backup_file_path}.gz"
            if [ $? -eq 0 ]; then
                log_info "Successfully backed up and compressed $db_name database"
                rm -f "$temp_backup"
            else
                log_error "Failed to compress backup for $db_name database"
                mv "$temp_backup" "$backup_file_path"
            fi
        else
            log_error "Failed to backup $db_name database (exit code: $exit_code)"
            rm -f "$temp_backup"
            return 1
        fi
    else
        log_error "Unable to backup $db_name database as $db_service_name container is not running"
        return 1
    fi
}

function backup_container_file_system() {
    local service_name=$1
    local container_file_path=$2
    local backup_file_path=$3
    
    if [[ $(is_compose_container_present $service_name) -eq 1 ]]; then
        docker compose cp -a "$service_name:$container_file_path" "$backup_file_path"
        if [ $? -eq 0 ]; then
            log_info "Successfully backed up files from $container_file_path"
            # Create a tar.gz archive of the backed up files
            cd "$backup_file_path" && tar -czf "${container_file_path##*/}.tar.gz" . && cd -
            if [ $? -eq 0 ]; then
                log_info "Successfully compressed backup from $container_file_path"
                # Clean up original files after compression
                rm -rf "$backup_file_path"/*
                mv "${backup_file_path}/${container_file_path##*/}.tar.gz" "$backup_file_path/"
            else
                log_warning "Failed to compress backup from $container_file_path"
            fi
        else
            log_error "Failed to backup files from $container_file_path"
        fi
    else
        log_error "Unable to backup from $service_name as container is not present"
    fi
}

function verify_backup() {
    local backup_path=$1
    if [ ! -f "$backup_path" ]; then
        log_error "Backup file not found at $backup_path"
        return 1
    fi
    if [ ! -s "$backup_path" ]; then
        log_error "Backup file at $backup_path is empty"
        return 1
    fi
    
    # Check if it's a compressed file
    if [[ "$backup_path" =~ \.(gz|tar\.gz)$ ]]; then
        if ! gzip -t "$backup_path" 2>/dev/null; then
            log_error "Backup file at $backup_path is corrupted"
            return 1
        fi
    fi
    
    log_info "Verified backup at $backup_path"
    return 0
}
