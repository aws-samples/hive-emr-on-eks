#!/bin/bash

# Logging function
function log() {
    level=$1
    message=$2
    echo $(date '+%d-%m-%Y %H:%M:%S') [${level}] ${message}
}

# Configuration variables
SLEEP_DURATION=10
INITIAL_HEARTBEAT_TIMEOUT_THREASHOLD=60
HEARBEAT_TIMEOUT_THRESHOLD=16

function terminate_main_process() {
    log "INFO" "Terminating the HMS process..."
    pid=$(ps aux | grep HiveMetaStore | grep -v grep | awk '{print $2}')
    kill -SIGTERM $pid
}

function wait_for_file() {
    local file=$1
    log "INFO" "Waiting for file $file to appear..."
    start_wait=$(date +%s)

    while ! [[ -f "$file" ]]; do
        elapsed_wait=$(expr $(date +%s) - $start_wait)
        if [ "$elapsed_wait" -gt "$INITIAL_HEARTBEAT_TIMEOUT_THREASHOLD" ]; then
            log "ERROR" "File $file not found after $INITIAL_HEARTBEAT_TIMEOUT_THREASHOLD seconds; aborting"
            terminate_main_process
            exit 1
        fi
        sleep $SLEEP_DURATION
    done

    log "INFO" "Found file $file; watching for heartbeats..."
}

function monitor_heartbeat() {
    local file=$1

    while [[ -f "$file" ]]; do
        LAST_HEARTBEAT=$(stat -c %Y $file)
        ELAPSED_TIME_SINCE_AFTER_HEARTBEAT=$(expr $(date +%s) - $LAST_HEARTBEAT)

        if [ "$ELAPSED_TIME_SINCE_AFTER_HEARTBEAT" -gt "$HEARBEAT_TIMEOUT_THRESHOLD" ]; then
            log "WARN" "Last heartbeat to file $file was more than $HEARBEAT_TIMEOUT_THRESHOLD seconds ago at $LAST_HEARTBEAT; terminating"
            terminate_main_process
            exit 0
        fi
        sleep $SLEEP_DURATION
    done

    log "INFO" "The file $file doesn't exist anymore"
    terminate_main_process
}

# Main execution
FILE_TO_WATCH=$1
wait_for_file "$FILE_TO_WATCH"
monitor_heartbeat "$FILE_TO_WATCH"
exit 0