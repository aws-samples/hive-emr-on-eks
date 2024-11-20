#!/bin/bash
# FILE_TO_WATCH="/var/log/fluentd/main-container-terminated"
FILE_TO_WATCH=$1
INITIAL_HEARTBEAT_TIMEOUT_THREASHOLD=60
HEARBEAT_TIMEOUT_THRESHOLD=16
SLEEP_DURATION=10

function terminate_main_process() {
  echo "terminating the HMS process.."
  pid=$(ps aux | grep HiveMetaStore | grep -v grep | awk '{print $2}')
  kill -SIGTERM $pid
}
# Waiting for the first heartbeat sent by Spark main container
echo "Waiting for file $FILE_TO_WATCH to appear..."
start_wait=$(date +%s)
while ! [[ -f "$FILE_TO_WATCH" ]]; do
    elapsed_wait=$(expr $(date +%s) - $start_wait)
    if [ "$elapsed_wait" -gt "$INITIAL_HEARTBEAT_TIMEOUT_THREASHOLD" ]; then
        echo "File $FILE_TO_WATCH not found after $INITIAL_HEARTBEAT_TIMEOUT_THREASHOLD seconds; aborting"
        terminate_main_process
        exit 1
    fi
    sleep $SLEEP_DURATION;
done;
echo "Found file $FILE_TO_WATCH; watching for heartbeats..."

while [[ -f "$FILE_TO_WATCH" ]]; do
    LAST_HEARTBEAT=$(stat -c %Y $FILE_TO_WATCH)
    ELAPSED_TIME_SINCE_AFTER_HEARTBEAT=$(expr $(date +%s) - $LAST_HEARTBEAT)
    if [ "$ELAPSED_TIME_SINCE_AFTER_HEARTBEAT" -gt "$HEARBEAT_TIMEOUT_THRESHOLD" ]; then
        echo "Last heartbeat to file $FILE_TO_WATCH was more than $HEARBEAT_TIMEOUT_THRESHOLD seconds ago at $LAST_HEARTBEAT; terminating"
        terminate_main_process
        exit 0
    fi
    sleep $SLEEP_DURATION;
done;
# the file will be deleted once the fluentd container is terminated
echo "The file $FILE_TO_WATCH doesn't exist anymore;"
terminate_main_process
exit 0