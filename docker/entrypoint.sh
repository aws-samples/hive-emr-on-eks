#!/bin/bash

function log () {
    level=$1
    message=$2
    echo $(date  '+%d-%m-%Y %H:%M:%S') [${level}]  ${message}
}

function render_templates() {
  local  hive_conf_dir="${METASTORE_HOME}/conf"
  local hadoop_conf_dir="${HADOOP_HOME}/etc/hadoop"

  if [ -d ${hive_conf_dir}/templates ]; then
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


start_metastore (){
  local hive_start_cmd="/opt/hive-metastore/bin/start-metastore"
  log "INFO" "Starting Hive Metastore service. Command: ${hive_start_cmd}"
  exec "$hive_start_cmd"
}

render_templates
start_metastore

