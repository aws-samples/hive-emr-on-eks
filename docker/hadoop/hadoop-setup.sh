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

function hadoop_setup_init {
    export HADOOP_HOME=$HADOOP_BASE_DIR/apache-hadoop

    # updated later in hadoop_setup_update_conf_dir()
    # do not set YARN_CONF_DIR and HADOOP_CLASSPATH which will be set in hadoop_setup_update_conf_dir()
    export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop

    export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
}

function hadoop_setup_update_conf_dir {
    conf_dir=$1

    cp -r $HADOOP_CONF_DIR/* $conf_dir 2> /dev/null
    rm -f $conf_dir/*.template
    rm -f $conf_dir/*.example
    rm -f $conf_dir/*.cmd

    # set HADOOP_CONF_DIR and YARN_CONF_DIR to prevent hadoop from injecting a default directory into CLASSPATH 
    # setting to ":" is okay because HIVE_CONF_DIR is properly set 
    # Cf. 'hadoop' later adds HADOOP_CONF_DIR to CLASSPATH, so do not add to HADOOP_CLASSPATH
    export HADOOP_CONF_DIR=":"
    export YARN_CONF_DIR=":"
}

