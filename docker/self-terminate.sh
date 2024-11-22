#!/bin/bash

# Environment variables with defaults and internal mapping
: "${SELF_TERMINATE_FILE:=/var/log/fluentd/main-container-terminated}"
: "${SELF_TERMINATE_INTERVAL:=5}"
: "${SELF_TERMINATE_INIT_TIMEOUT:=60}"
: "${SELF_TERMINATE_HEARTBEAT_TIMEOUT:=10}"

# Check for command line argument first (backwards compatibility)
if [ -n "$1" ]; then
    FILE_TO_WATCH=$1
else
    FILE_TO_WATCH=$SELF_TERMINATE_FILE
fi
# Map environment variables to internal variables
SLEEP_DURATION=$SELF_TERMINATE_INTERVAL
INITIAL_TIMEOUT=$SELF_TERMINATE_INIT_TIMEOUT
HEARTBEAT_TIMEOUT=$SELF_TERMINATE_HEARTBEAT_TIMEOUT

function show_help() {
    cat << EOF
Name:
    self-terminate.sh - Monitor a file for heartbeats and terminate HiveMetaStore process

Description:
    This script monitors a specified file for heartbeats and terminates the HiveMetaStore process if the file is
    missing or if heartbeats stop. It first waits for the file to appear, then continuously checks its last modification
    time. If the file hasn't been updated within the heartbeat timeout period, or if the file disappears, the script
    sends SIGTERM to the HiveMetaStore process.

Usage:
    $0 [FILE_PATH]           Specify file path as argument (legacy mode)
    $0 --help|-h             Show this help message

Environment Variables:
    SELF_TERMINATE_FILE      File to monitor for heartbeats
                             Default: $SELF_TERMINATE_FILE

    SELF_TERMINATE_INTERVAL  Sleep duration between checks in seconds
                             Default: $SELF_TERMINATE_INTERVAL

    SELF_TERMINATE_INIT_TIMEOUT
                             Maximum time to wait for file to appear in seconds
                             Default: $SELF_TERMINATE_INIT_TIMEOUT

    SELF_TERMINATE_HEARTBEAT_TIMEOUT
                             Maximum time between file updates in seconds
                             Default: $SELF_TERMINATE_HEARTBEAT_TIMEOUT

Exit Status:
    0  Normal termination
    1  Error (file not found within timeout)

Example:
    # Using environment variables:
    export SELF_TERMINATE_FILE=/path/to/heartbeat
    export SELF_TERMINATE_HEARTBEAT_TIMEOUT=30
    $0

    # Or inline:
    SELF_TERMINATE_FILE=/path/to/heartbeat SELF_TERMINATE_HEARTBEAT_TIMEOUT=30 $0
EOF
    exit 0
}

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
fi

# Logging function
function log () {
    level=$1
    message=$2
    echo $(date '+%d/%m/%y %H:%M:%S') [${level}]  ${message}
}

function terminate_main_process() {
    log "INFO" "Terminating the HMS process..."
    pid=$(ps aux | grep HiveMetaStore | grep -v grep | awk '{print $2}')
    kill -SIGTERM $pid
}

function wait_for_file() {
    local file=$1
    local elapsed_wait

    log "INFO" "Waiting for file $file to appear..."
    start_wait=$(date +%s)

    while ! [[ -f "$file" ]]; do
        elapsed_wait=$(expr $(date +%s) - $start_wait)
        if [ "$elapsed_wait" -gt "$INITIAL_TIMEOUT" ]; then
            log "ERROR" "File $file not found after $INITIAL_TIMEOUT seconds; aborting"
            terminate_main_process
            exit 1
        fi
        sleep "$SLEEP_DURATION"
    done

    log "INFO" "Found file $file; watching for heartbeats..."
}

function monitor_heartbeat() {
    local file=$1
    local elapsed_wait
    local last_heartbeat

    while [[ -f "$file" ]]; do
        last_heartbeat=$(stat -c %Y $file)
        elapsed_wait=$(expr $(date +%s) - "$last_heartbeat")

        if [ "$elapsed_wait" -gt "$HEARTBEAT_TIMEOUT" ]; then
            log "WARN" "Last heartbeat to file $file was more than $HEARTBEAT_TIMEOUT seconds ago at $last_heartbeat; terminating"
            terminate_main_process
            exit 0
        fi
        sleep "$SLEEP_DURATION"
    done

    log "INFO" "The file $file doesn't exist anymore"
    terminate_main_process
}

# Log current configuration
log "INFO" "Starting self-terminate monitor with configuration:"
log "INFO" "- File to watch: $FILE_TO_WATCH"
log "INFO" "- Check interval: $SLEEP_DURATION seconds"
log "INFO" "- Initial timeout: $INITIAL_TIMEOUT seconds"
log "INFO" "- Heartbeat timeout: $HEARTBEAT_TIMEOUT seconds"

# Main execution
wait_for_file "$FILE_TO_WATCH"
monitor_heartbeat "$FILE_TO_WATCH"
exit 0