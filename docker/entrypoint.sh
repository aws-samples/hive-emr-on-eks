#!/bin/bash

# Schema operation control variables
ENABLE_SCHEMA_CHECK=${ENABLE_SCHEMA_CHECK:-false}
AUTO_INIT_SCHEMA=${AUTO_INIT_SCHEMA:-false}

# Self-terminate control variables
ENABLE_SELF_TERMINATE=${ENABLE_SELF_TERMINATE:-false}
SELF_TERMINATE_FILE=${SELF_TERMINATE_FILE:-"/var/log/fluentd/main-container-terminated"}
SELF_TERMINATE_INTERVAL=${SELF_TERMINATE_INTERVAL:-5}
SELF_TERMINATE_INIT_TIMEOUT=${SELF_TERMINATE_INIT_TIMEOUT:-60}
SELF_TERMINATE_HEARTBEAT_TIMEOUT=${SELF_TERMINATE_HEARTBEAT_TIMEOUT:-10}

# Verbose flag control
VERBOSE=${VERBOSE:-false}

function show_help() {
    cat << EOF
Name:
    entrypoint.sh - Start Hive Metastore service with schema and self-terminate controls

Description:
    This script initializes and starts the Hive Metastore service with configurable schema
    validation and self-termination behavior. It handles template rendering, schema operations,
    and graceful termination based on heartbeat monitoring.

Environment Variables:

Schema Control:
    ENABLE_SCHEMA_CHECK      Run schema check operations if true
                             Default: $ENABLE_SCHEMA_CHECK
                             Note: Skip all schema operations if false
                                   Required to be true for AUTO_INIT_SCHEMA to work

    AUTO_INIT_SCHEMA         Initialize schema if not present (requires ENABLE_SCHEMA_CHECK=true)
                             Default: $AUTO_INIT_SCHEMA
                             Note: Skip init schema operations if ENABLE_SCHEMA_CHECK=false
                                   Requires ENABLE_SCHEMA_CHECK=true to work

Self-Terminate Control:
    ENABLE_SELF_TERMINATE    Enable self-terminate functionality
                             Default: $ENABLE_SELF_TERMINATE

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

Logging Control:
    VERBOSE                 Enable verbose logging if true
                            Default: $VERBOSE

Options:
    --help                  Display this help message

Example:
    # Skip schema checks and customize self-terminate settings
    export ENABLE_SCHEMA_CHECK=false
    export SELF_TERMINATE_INTERVAL=10
    export SELF_TERMINATE_HEARTBEAT_TIMEOUT=30
    ./entrypoint.sh

    # Disable self-terminate and enable auto schema init with verbose logging
    export ENABLE_SELF_TERMINATE=false
    export AUTO_INIT_SCHEMA=true
    export VERBOSE=true
    ./entrypoint.sh
EOF
    exit 0
}


# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
fi


function log () {
    level=$1
    message=$2
    echo $(date '+%d/%m/%y %H:%M:%S') [${level}]  ${message}
}


function render_templates() {
  local hive_conf_dir="${METASTORE_HOME}/conf"
  local hadoop_conf_dir="${HADOOP_HOME}/etc/hadoop"

  if [ -d ${hive_conf_dir}/templates ]; then
    AWS_SDK_VERSION=$(cat "${METASTORE_HOME}/conf/aws_sdk_version")
    export AWS_SDK_VERSION
    log "INFO" "AWS SDK Version: $AWS_SDK_VERSION"
    log "INFO" "🤖- Te(Go)mplating files!"
    log "INFO" "🗃️- Files to templating:"
    log "INFO" $(find ${hive_conf_dir}/templates/* -maxdepth 1)
    for file in $(ls -1 ${hive_conf_dir}/templates | grep -E '\.tpl$'); do
      log "INFO" "🚀- Templating $file"
      out_file=${file%%.tpl}
      if [[ "$file" =~ ^core-site ]]; then
        log "INFO" "🚀- Moving core-site to $hadoop_conf_dir/$out_file"
        gomplate -f ${hive_conf_dir}/templates/${file} -o ${hadoop_conf_dir}/${out_file}
      else
        gomplate -f ${hive_conf_dir}/templates/${file} -o ${hive_conf_dir}/${out_file}
      fi
      if [ $? -ne 0 ]; then
        log "ERROR" "Error rendering config template file ${hive_conf_dir}/${out_file}. Aborting."
        exit 1
      fi
      log "INFO" "Generated config file from template in ${hive_conf_dir}/${out_file}"
    done
  fi
}


function init_schema() {
  local hive_cmd
  hive_cmd="/opt/hive-metastore/bin/schematool -dbType mysql -initSchema -verbose"
  log "INFO" "Starting Hive Metastore initialisation. Command: ${hive_cmd}"
  /bin/bash -c "$hive_cmd"
  log "INFO" "Starting Hive Metastore initialisation finished."
}


function validate_schema() {
  local hive_cmd
  hive_cmd="/opt/hive-metastore/bin/schematool -dbType mysql -validate"
  log "INFO" "Starting Hive Metastore validation. Command: ${hive_cmd}"
  /bin/bash -c "$hive_cmd"
  log "INFO" "Starting Hive Metastore validation finished."
}


function run_schema_tool() {
  if [ "${ENABLE_SCHEMA_CHECK}" = "false" ]; then
    log "INFO" "Skipping schema operations (ENABLE_SCHEMA_CHECK is false)"
    return
  fi

  if [ "${AUTO_INIT_SCHEMA}" = "true" ]; then
    if /opt/hive-metastore/bin/schematool -dbType mysql -info >/dev/null 2>&1; then
      log "INFO" "Database initialized"
      validate_schema
    else
      log "INFO" "Database not initialized"
      init_schema
      validate_schema
    fi
  else
    log "INFO" "Skipping auto-init (AUTO_INIT_SCHEMA is false)"
    validate_schema
  fi
}

function start_metastore() {
  local verbose_flag=""
  if [ "${VERBOSE}" = "true" ]; then
    verbose_flag="--verbose"
  fi

  local hive_start_cmd="/opt/hive-metastore/bin/start-metastore ${verbose_flag}"
  local self_terminate_cmd="/opt/hive-metastore/bin/self-terminate.sh"

  if [ "${ENABLE_SELF_TERMINATE}" = "true" ]; then
    log "INFO" "Starting Hive Metastore service with self-terminate enabled:"
    log "INFO" "- File to watch: ${SELF_TERMINATE_FILE}"
    log "INFO" "- Check interval: ${SELF_TERMINATE_INTERVAL} seconds"
    log "INFO" "- Initial timeout: ${SELF_TERMINATE_INIT_TIMEOUT} seconds"
    log "INFO" "- Heartbeat timeout: ${SELF_TERMINATE_HEARTBEAT_TIMEOUT} seconds"
    [ "${VERBOSE}" = "true" ] && log "INFO" "- Verbose logging: enabled"

    # Export self-terminate variables
    export SELF_TERMINATE_FILE
    export SELF_TERMINATE_INTERVAL
    export SELF_TERMINATE_INIT_TIMEOUT
    export SELF_TERMINATE_HEARTBEAT_TIMEOUT

    "$hive_start_cmd" & "$self_terminate_cmd" & wait
  else
    log "INFO" "Starting Hive Metastore service (self-terminate disabled)"
    [ "${VERBOSE}" = "true" ] && log "INFO" "- Verbose logging: enabled"
    "$hive_start_cmd" & wait
  fi
}


render_templates
run_schema_tool
start_metastore
