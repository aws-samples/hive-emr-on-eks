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
BASE_DIR=$(readlink -f $DIR)

source $BASE_DIR/key/solr.in.sh

function setup_solr() {
    cp /opt/mr3-run/ranger/conf/krb5.conf /etc/krb5.conf

    solr_ranger_core=ranger_audits

    mkdir -p $SOLR_HOME
    mkdir $SOLR_HOME/resources
    mkdir $SOLR_HOME/$solr_ranger_core
    mkdir $SOLR_HOME/$solr_ranger_core/conf
    cp $BASE_DIR/conf/solr-log4j2.xml $SOLR_HOME/resources/log4j2.xml
    cp $BASE_DIR/conf/solr-elevate.xml $SOLR_HOME/$solr_ranger_core/conf/elevate.xml
    cp $BASE_DIR/conf/solr-managed-schema $SOLR_HOME/$solr_ranger_core/conf/managed-schema
    cp $BASE_DIR/conf/solr-solrconfig.xml $SOLR_HOME/$solr_ranger_core/conf/solrconfig.xml
    cp $BASE_DIR/conf/solr-core.properties $SOLR_HOME/$solr_ranger_core/core.properties
    cp $BASE_DIR/conf/solr-security.json $SOLR_HOME/security.json
    cp $BASE_DIR/conf/solr-solr.xml $SOLR_HOME/solr.xml

    mkdir -p $SOLR_DATA_HOME
    mkdir -p $SOLR_LOGS_DIR
}

function start_solr() {
    SOLR_INCLUDE=$BASE_DIR/key/solr.in.sh $BASE_DIR/solr/bin/solr start -f -force
}

function main {
    setup_solr
    start_solr
}

main $@
