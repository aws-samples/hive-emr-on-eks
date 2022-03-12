#!/bin/bash

function log () {
    level=$1
    message=$2
    echo $(date  '+%d-%m-%Y %H:%M:%S') [${level}]  ${message}
}

HIVE_CONF_DIR="${METASTORE_HOME}/conf"
HADOOP_CONF_DIR="${HADOOP_HOME}/etc/hadoop"

if [ -d ${HIVE_CONF_DIR}/templates ]; then
  log "INFO" "🤖- Te(Go)mplating files!"
  log "INFO" "🗃️- Files to templating:"
  log "INFO" $(find ${HIVE_CONF_DIR}/templates/* -maxdepth 1)
  for file in $(ls -1 ${HIVE_CONF_DIR}/templates | grep -E '\.tpl$'); do
    log "INFO" "🚀- Templating $file"
    out_file=${file%%.tpl}
    if [[ "$file" =~ ^core-site ]]; then
      log "INFO" "🚀- Moving core-site to $HADOOP_CONF_DIR/$out_file"
      gomplate -f ${HIVE_CONF_DIR}/templates/${file} -o ${HADOOP_CONF_DIR}/${out_file}
    else
      gomplate -f ${HIVE_CONF_DIR}/templates/${file} -o ${HIVE_CONF_DIR}/${out_file}
    fi
    if [ $? -ne 0 ]; then
      log "ERROR" "Error rendering config template file ${HIVE_CONF_DIR}/${out_file}. Aborting."
      exit 1
    fi
    log "INFO" "Generated config file from template in ${HIVE_CONF_DIR}/${out_file}"
  done
fi

HIVE_START_CMD="/opt/hive-metastore/bin/start-metastore"

log "INFO" "Starting Hive Metastore service. Command: ${HIVE_START_CMD}"

exec "$HIVE_START_CMD"
