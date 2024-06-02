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

function hive_setup_print_usage_conf_mode {
    echo " --localthread                          Run MR3 inside Hive as a local thread"
    echo " --localprocess                         Run MR3 inside Hive as a local process"
    echo " --kubernetes                           Run MR3 inside Hive as a Pod"
}

function hive_setup_print_usage_hiveconf {
    echo " --hiveconf <key>=<value>               Add a configuration key/value; may be repeated at the end."
}

function hive_setup_parse_args_common {
    LOCAL_MODE="local-thread"

    while ! [[ -z $1 ]]; do
        case "$1" in
            --localthread)
                LOCAL_MODE="local-thread"
                shift
                ;;
            --localprocess)
                LOCAL_MODE="local-process"
                shift
                ;;
            --kubernetes)
                LOCAL_MODE="kubernetes"
                shift
                ;;
            --conf|--hiveconf)
                export HIVE_OPTS="$HIVE_OPTS ${@//--conf/--hiveconf}"
                shift 2
                ;;
            *)
                REMAINING_ARGS="$REMAINING_ARGS $1"
                shift
                ;;
        esac
    done
}

#
# hive_setup_init and hive_setup_init_heapsize_mb
#

function hive_setup_init {
    export HIVE_HOME=$HIVE_BASE_DIR/apache-hive
    HIVE_JARS=$HIVE_HOME/lib
    HIVE_BIN=$HIVE_HOME/bin
    HCATALOG_CONF_DIR=$HIVE_HOME/hcatalog/etc/hcatalog
    HCATALOG_JARS=$HIVE_HOME/hcatalog/share/hcatalog

    # updated later in hive_setup_update_conf_dir()
    # do not include HIVE_CONF_DIR in HIVE_CLASSPATH 
    export HIVE_CONF_DIR=$HIVE_HOME/conf
    # do not include HIVE_JARS/* because it will be added when interpreting HIVE_HOME
    export HIVE_CLASSPATH=$HCATALOG_CONF_DIR:$HCATALOG_JARS/*

    export PATH=$HIVE_BIN:$PATH

    export HADOOP_CLIENT_OPTS="$HADOOP_CLIENT_OPTS -Dlog4j.configurationFile=hive-log4j2.properties"
}

function hive_setup_init_heapsize_mb {
    heapsize=$1

    export HADOOP_CLIENT_OPTS="-Xmx${heapsize}m $HIVE_MR3_JVM_OPTION $HADOOP_CLIENT_OPTS"
}

#
# hive_setup_init_output_dir
#

function hive_setup_init_output_dir {
    output_dir=$1

    mkdir -p $output_dir > /dev/null 2>&1

    hive_setup_create_output_dir $output_dir 

    OUT_CONF=$OUT/conf
    mkdir -p $OUT_CONF > /dev/null 2>&1

    cp $BASE_DIR/env.sh $OUT_CONF
    hadoop_setup_update_conf_dir $OUT_CONF 
    hive_setup_update_conf_dir $OUT_CONF
    common_setup_update_conf_dir $OUT_CONF 
}

function hive_setup_create_output_dir {
    base_dir=$1

    time_stamp="$(date +"%Y-%m-%d-%H-%M-%S")"
    export OUT=$base_dir/hivemr3-$time_stamp
    mkdir -p $OUT > /dev/null 2>&1
    echo -e "Output directory: $OUT"
}

function hive_setup_update_conf_dir {
    conf_dir=$1

    cp -r $HIVE_CONF_DIR/* $conf_dir
    cp -r $HCATALOG_CONF_DIR/* $conf_dir
    rm -f $conf_dir/*.template

    # update HIVE_CONF_DIR
    export HIVE_CONF_DIR=$conf_dir
    # no need to add HIVE_CONF_DIR to HIVE_CLASSPATH, which will be performed by 'hive' later
    # export HIVE_CLASSPATH=$HIVE_CONF_DIR:$HIVE_CLASSPATH

    # TEZ_CONF_DIR should be set to prevent 'hive' from adding a default path (/etc/tez/conf) to CLASSPATH
    # suffices to set it to ":" because HIVE_CONF_DIR already includes $conf_dir 
    export TEZ_CONF_DIR=":"

    # similarly for HBASE_CONF_DIR 
    export HBASE_CONF_DIR=":"
}

#
# hive_setup_config_hive_logs 
#
# With the default hive-log4j2.properties, hive_setup_config_hive_logs has no effect because logs are printed to 
# STDOUT. Still we call hive_setup_config_hive_logs in the case that another log4j2.properties file is provided.
#

function hive_setup_config_hive_logs {
    output_dir=$1
    log_filename="hive.log"

    mkdir -p $output_dir
    export HIVE_OPTS="--hiveconf hive.querylog.location=$output_dir $HIVE_OPTS"

    # Cf. HIVE-19886
    # HADOOP_OPTS should be updated because some LOG objects may be initialized before HiveServer2.main() calls 
    # LogUtils.initHiveLog4j(), e.g., conf.HiveConf.LOG. Without updating HADOOP_OPTS, these LOG objects send 
    # their output to hive.log in a default directory, e.g., /tmp/gitlab-runner/hive.log, and we end up with 
    # two hive.log files.
    export HADOOP_OPTS="$HADOOP_OPTS -Dhive.log.dir=$output_dir -Dhive.log.file=$log_filename"
}

#
# hive_setup_init_run_configs
#

function hive_setup_init_run_configs {
    local_mode=$1

    hive_setup_update_hadoop_opts $local_mode 
    hive_setup_metastore_update_hadoop_opts 
    hive_setup_config_hadoop_classpath
}

function hive_setup_update_hadoop_opts {
    local_mode=$1

    if [[ $local_mode = "local-thread" ]]; then
        export HADOOP_OPTS="$HADOOP_OPTS -Dmr3.root.logger=$LOG_LEVEL,console"
    fi

    mr3_setup_update_hadoop_opts $local_mode 
}

function hive_setup_metastore_update_hadoop_opts {
   export HADOOP_OPTS="$HADOOP_OPTS \
-Dhive.database.host=$HIVE_DATABASE_HOST \
-Dhive.metastore.host=$HIVE_METASTORE_HOST \
-Dhive.metastore.port=$HIVE_METASTORE_PORT \
-Dhive.database.name=$HIVE_DATABASE_NAME \
-Dhive.warehouse.dir=$HIVE_WAREHOUSE_DIR \
-Dhive.metastore.secure.mode=$METASTORE_SECURE_MODE \
-Dhive.metastore.keytab.file=$HIVE_METASTORE_KERBEROS_KEYTAB \
-Dhive.metastore.principal=$HIVE_METASTORE_KERBEROS_PRINCIPAL \
-Dhive.server2.host=$HIVE_SERVER2_HOST \
-Dhive.server2.port=$HIVE_SERVER2_PORT \
-Dhive.server2.http.port=$HIVE_SERVER2_HTTP_PORT \
-Dhive.server2.authentication.mode=$HIVE_SERVER2_AUTHENTICATION \
-Dhive.server2.keytab.file=$HIVE_SERVER2_KERBEROS_KEYTAB \
-Dhive.server2.principal=$HIVE_SERVER2_KERBEROS_PRINCIPAL \
-Djavax.security.auth.useSubjectCredsOnly=false \
-Djava.security.auth.login.config=$REMOTE_BASE_DIR/conf/jgss.conf \
-Djava.security.krb5.conf=$REMOTE_BASE_DIR/conf/krb5.conf \
-Dsun.security.jgss.debug=true"

    # We should use hadoop.login=hybrid on those nodes where Beeline is installed
    if [[ $HIVE_SERVER2_AUTHENTICATION = "KERBEROS" ]]; then
        export HADOOP_OPTS="$HADOOP_OPTS -Dhadoop.login=hybrid"
    fi

    if [ -f $HIVE_SERVER2_SSL_TRUSTSTORE ]; then
      export HADOOP_OPTS="$HADOOP_OPTS \
-Djavax.net.ssl.trustStore=$HIVE_SERVER2_SSL_TRUSTSTORE \
-Djavax.net.ssl.trustStoreType=$HIVE_SERVER2_SSL_TRUSTSTORETYPE \
-Djavax.net.ssl.trustStorePassword=$HIVE_SERVER2_SSL_TRUSTSTOREPASS"
    fi
}

function hive_setup_beeline_update_hadoop_opts {
   export HADOOP_OPTS="$HADOOP_OPTS \
-Dhive.database.host=$HIVE_DATABASE_HOST \
-Dhive.metastore.host=$HIVE_METASTORE_HOST \
-Dhive.metastore.port=$HIVE_METASTORE_PORT \
-Dhive.database.name=$HIVE_DATABASE_NAME \
-Dhive.warehouse.dir=$HIVE_WAREHOUSE_DIR \
-Dhive.metastore.secure.mode=$METASTORE_SECURE_MODE \
-Dhive.metastore.keytab.file=$HIVE_METASTORE_KERBEROS_KEYTAB \
-Dhive.metastore.principal=$HIVE_METASTORE_KERBEROS_PRINCIPAL"

    # We should use hadoop.login=hybrid on those nodes where Beeline is installed
    if [[ $HIVE_SERVER2_AUTHENTICATION = "KERBEROS" ]]; then
        export HADOOP_OPTS="$HADOOP_OPTS -Dhadoop.login=hybrid"
    fi

    # TODO: remove the following block which seems unnecessary for running Beeline
    if [ -f $HIVE_SERVER2_SSL_TRUSTSTORE ]; then
      export HADOOP_OPTS="$HADOOP_OPTS \
-Djavax.net.ssl.trustStore=$HIVE_SERVER2_SSL_TRUSTSTORE \
-Djavax.net.ssl.trustStoreType=$HIVE_SERVER2_SSL_TRUSTSTORETYPE \
-Djavax.net.ssl.trustStorePassword=$HIVE_SERVER2_SSL_TRUSTSTOREPASS"
    fi
}

function hive_setup_config_hadoop_classpath {
    # do not include HIVE_CLASSPATH which is added to HADOOP_CLASSPATH by hive command
    export HADOOP_CLASSPATH=$MR3_CLASSPATH:$TEZ_CLASSPATH:$BASE_DIR/lib/*:$HADOOP_CLASSPATH:$BASE_DIR/host-lib/*:$HIVE_JARS/ranger-hive-plugin-impl/*
}

#
# hive_setup_exec_cmd
#

function hive_setup_exec_cmd {
    cmd=$1

    EXEC_EXIT_CODE=0
    EXEC_TIMED_RUN_TIME=0
    EXEC_TIMED_RUN_START=$(date -u +%s%3N)
    eval "$cmd"
    EXEC_EXIT_CODE=$?
    EXEC_TIMED_RUN_STOP=$(date -u +%s%3N)
    elapsed_raw=$((EXEC_TIMED_RUN_STOP-$EXEC_TIMED_RUN_START))
    EXEC_TIMED_RUN_TIME="$((elapsed_raw / 1000)).$((elapsed_raw % 1000))"
    echo "execution time: $EXEC_TIMED_RUN_TIME"

    return $EXEC_EXIT_CODE
}

