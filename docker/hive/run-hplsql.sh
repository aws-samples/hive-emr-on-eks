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

function print_usage {
    echo "Usage: run-hplsql.sh [command] [option(s)]"
    common_setup_print_usage_common_options
    common_setup_print_usage_conf_mode
    hive_setup_print_usage_hivesrc
    hive_setup_print_usage_hiveconf
    echo " <HPL/SQL option>                       Add an HPL/SQL option; may be repeated at the end."
    echo ""
    echo "Example: ./run-hplsql.sh --tpcds --hivesrc3 -e \"select name from \$database;\""
    echo ""
}

function error {
    common_setup_log_error ${FUNCNAME[1]} "$1"
    exit 1
}

function parse_args {
    while [ "${1+defined}" ]; do
      case "$1" in
        -h|--help)
          print_usage
          exit 1
          ;;
        -e)
          # Currently the script passes everything after -e as a query to HPL/SQL.
          #
          # Ex. does not work because '-d a=Hello -d b=Hivemr3' becomes a part of the query.
          #   ./run-hplsql.sh -e "PRINT a || ', ' || b" -d a=Hello -d b=Hivemr3
          #
          # Ex. works okay: 
          #   ./run-hplsql.sh -d a=Hello -d b=Hivemr3 -e "PRINT a || ', ' || b"
          shift
          hplsql_query=$@
          break
          ;;
        -f)
          hplsql_file="$1 $2"
          shift 2
          ;;
        *)
          hplsql_opts="${hplsql_opts} $1"
          shift
          ;;
      esac
    done
    if [[ -z "$hplsql_opts" ]] && [[ -z "$hplsql_query" ]] && [[ -z "$hplsql_file" ]]; then
      error "command not provided"
    fi
}

function run_hplsql_init {
    hadoop_setup_init
    tez_setup_init
    hive_setup_init

    BASE_OUT=$HIVE_BASE_DIR/run-hplsql-result
    hive_setup_init_output_dir $BASE_OUT
}

function run_hplsql_start {
    if [[ -z $hplsql_query ]]; then
        hive --service hplsql --skiphbasecp $HIVE_OPTS $hplsql_opts $hplsql_file
    else
        hive --service hplsql --skiphbasecp $HIVE_OPTS $hplsql_opts -e "\"$hplsql_query\""
    fi
    return $?
}

function main {
    RUN_BEELINE=true    # to suppress '--hiveconf mr3.runtime=tez'                 
    hive_setup_parse_args_common $@
    parse_args $REMAINING_ARGS

    run_hplsql_init

    echo -e "\n# Running HPL/SQL using Hive-MR3 #\n"
    hive_setup_init_run_configs $LOCAL_MODE

    pushd $BASE_DIR > /dev/null

    run_hplsql_start
    exit_code=$?

    popd > /dev/null

    exit $exit_code
}

main $@
