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
source $BASE_DIR/common-setup.sh
source $HADOOP_BASE_DIR/hadoop-setup.sh
source $TEZ_BASE_DIR/tez-setup.sh
source $MR3_BASE_DIR/mr3-setup.sh
source $HIVE_BASE_DIR/hive-setup.sh

function run_hive_cli_error {
    common_setup_log_error ${FUNCNAME[1]} "$1"
    run_hive_cli_print_usage
    exit 1
}

function run_hive_cli_print_usage {
    echo "Usage: run-hive-cli.sh [option(s)]"
    common_setup_print_usage_common_options
    hive_setup_print_usage_conf_mode
    hive_setup_print_usage_hiveconf
    echo " <HiveCLI option>                       Add a HiveCLI option; may be repeated at the end."
    echo "" 
}

function run_hive_cli_parse_args {
    while [ "${1+defined}" ]; do
        case "$1" in
            -h|--help)
                run_hive_cli_print_usage
                exit 1
                ;;
            *)
                export HIVE_OPTS="$HIVE_OPTS $@"
                break
                ;;
        esac
    done
}

function run_hive_cli_init {
    hadoop_setup_init
    tez_setup_init
    mr3_setup_init
    hive_setup_init

    hive_setup_init_heapsize_mb $HIVE_CLIENT_HEAPSIZE

    echo -e "\n# Running HiveCLI using Hive on MR3 #\n" >&2
    BASE_OUT=$HIVE_BASE_DIR/run-result
    hive_setup_init_output_dir $BASE_OUT

    common_setup_cleanup 
}

function run_hive_cli_start {
    return_code=0

    run_dir=$OUT
    mkdir -p $run_dir

    # With the default hive-log4j2.properties, hive_log_dir and log_filename have no effect.
    hive_log_dir=$run_dir/hive-logs
    log_filename="hive.log"
    cmd="hive \
--hiveconf hive.log.dir=$hive_log_dir \
--hiveconf hive.log.fille=$log_filename \
--hiveconf hive.querylog.location=$hive_log_dir"

    hive_setup_exec_cmd "$cmd" 
    return $?
}

function run_hive_cli_main {
    hive_setup_parse_args_common $@
    run_hive_cli_parse_args $REMAINING_ARGS
    run_hive_cli_init

    pushd $BASE_DIR > /dev/null

    hive_setup_init_run_configs $LOCAL_MODE 

    run_hive_cli_start
    exit_code=$?

    popd > /dev/null

    exit $exit_code
}

run_hive_cli_main $@
