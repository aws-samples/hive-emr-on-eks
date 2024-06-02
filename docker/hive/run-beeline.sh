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

set +e 
set +x

# make sure that environment variable USER is set

function run_beeline_print_usage {
    echo "Usage: run-beeline.sh [option(s)]"
    common_setup_print_usage_common_options
    hive_setup_print_usage_hiveconf
    echo " --ssl <KeyStore file>                  Connect to SSL enabled HiveServer2 with given TrustStore."
    echo " <Beeline option>                       Add a Beeline option; may be repeated at the end."
    echo "" 
}

function run_beeline_parse_args {
    while [ "${1+defined}" ]; do
        case "$1" in
            -h|--help)
                run_beeline_print_usage
                exit 1
                ;;
            --ssl)
                export ssl_options="ssl=true;sslTrustStore=$2"
                shift 2
                ;;
            *)
                export HIVE_OPTS="$HIVE_OPTS $@"
                break
                ;;
        esac
    done
}

function run_beeline_init {
    hadoop_setup_init
    tez_setup_init
    mr3_setup_init
    hive_setup_init

    hive_setup_init_heapsize_mb $HIVE_CLIENT_HEAPSIZE

    BASE_OUT=$HIVE_BASE_DIR/run-result
    hive_setup_init_output_dir $BASE_OUT
}

function run_beeline_start {
    return_code=0

    run_dir=$OUT
    output_file=$run_dir/out.txt
    hive_log_dir=$run_dir/hive-logs
    mkdir -p $run_dir

    hiveserver2_host=${HIVE_SERVER2_HOST_CUSTOM:-$HIVE_SERVER2_HOST}
    hiveserver2_port=${HIVE_SERVER2_PORT_CUSTOM:-$HIVE_SERVER2_PORT}
    if [[ $HIVE_SERVER2_AUTHENTICATION = KERBEROS ]]; then
        principal_name="principal=${HIVE_SERVER2_KERBEROS_PRINCIPAL_CUSTOM:-$HIVE_SERVER2_KERBEROS_PRINCIPAL}"
    else
        principal_name=""
    fi
    jdbc_options=$HIVE_SERVER2_JDBC_OPTS

    cmd="beeline -u \"jdbc:hive2://$hiveserver2_host:$hiveserver2_port/;${principal_name};${jdbc_options};${ssl_options}\" -n $USER -p $USER \
--hiveconf hive.querylog.location=$hive_log_dir"
    echo $cmd
    eval $cmd

    return $?
}

function run_beeline_main {
    hive_setup_parse_args_common $@
    run_beeline_parse_args $REMAINING_ARGS
    run_beeline_init

    hive_setup_beeline_update_hadoop_opts
    hive_setup_config_hadoop_classpath

    pushd $BASE_DIR > /dev/null
    echo -e "\n# Running Beeline using Hive-MR3 #\n" >&2
    run_beeline_start
    exit_code=$?
    popd > /dev/null

    exit $exit_code
}

run_beeline_main $@
