#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR=$(readlink -f $DIR/..)
source $BASE_DIR/env.sh
if [[ -f "$BASE_DIR/env-secret.sh" ]]; then
  source $BASE_DIR/env-secret.sh
fi
source $BASE_DIR/common-setup.sh
source $HADOOP_BASE_DIR/hadoop-setup.sh
source $TEZ_BASE_DIR/tez-setup.sh
source $MR3_BASE_DIR/mr3-setup.sh
source $HIVE_BASE_DIR/hive-setup.sh

function print_usage {
    echo "Usage: hiveserver2-service.sh [command] [option(s)]"
    echo " start                                  Start HiveServer2 on port defined in HIVE_SERVER2_PORT/HIVE_SERVER2_HTTP_PORT."
    common_setup_print_usage_common_options
    hive_setup_print_usage_conf_mode
    hive_setup_print_usage_hiveconf
    echo " <HiveServer2 option>                   Add a HiveServer2 option; may be repeated at the end."
    echo ""
}

function warning {
    common_setup_log_warning ${FUNCNAME[1]} "$1"
}

function error {
    common_setup_log_error ${FUNCNAME[1]} "$1"
    print_usage
    exit 1
}

function hiveserver2_service_parse_args {
    if [ $# = 0 ]; then
       print_usage
       exit 1
    fi

    START_HIVE_SERVER2=false

    while [ "${1+defined}" ]; do
      case "$1" in
        -h|--help)
          print_usage
          exit 1
          ;;
        start)
          START_HIVE_SERVER2=true
          shift
          ;;
        *)
          export HIVE_OPTS="$HIVE_OPTS $@"
          break
          ;;
      esac
    done

    if [ $START_HIVE_SERVER2 = false ]; then
        error "command not provided"
    fi
}

function hiveserver2_service_init {
    hadoop_setup_init
    tez_setup_init
    mr3_setup_init
    hive_setup_init

    hive_setup_init_heapsize_mb $HIVE_SERVER2_HEAPSIZE

    echo -e "\n# Running HiveServer2 using Hive on MR3 #\n" >&2
    BASE_OUT=$HIVE_BASE_DIR/run-result
    hive_setup_init_output_dir $BASE_OUT

    common_setup_cleanup 
}

function start_hiveserver2 {
    return_code=0
    echo "Starting HiveServer2 on port $HIVE_SERVER2_PORT/$HIVE_SERVER2_HTTP_PORT..."
    hive --service hiveserver2 --skiphbasecp
    return $return_code
}

function main {
    hive_setup_parse_args_common $@
    hiveserver2_service_parse_args $REMAINING_ARGS
    hiveserver2_service_init

    log_dir="$OUT/hive-logs"

    hive_setup_config_hive_logs "$log_dir"
    hive_setup_init_run_configs $LOCAL_MODE 

    return_code=0

    # HTTP2_DISABLE=false is now okay with fabric8io/kubernetes-client to 4.9.2+
    export HTTP2_DISABLE=true

    if [ $START_HIVE_SERVER2 = true ]; then
      echo "Starting HiveServer2..." >&2
      start_hiveserver2
      [ $? != 0 ] && let return_code=1
    fi

    exit $return_code
}

main $@
