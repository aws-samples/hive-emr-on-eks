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

# get current dir of this script and mr3-run dir
DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR=$(readlink -f $DIR/..)
source $BASE_DIR/env.sh
# source $BASE_DIR/common-setup.sh
source $BASE_DIR/config-run.sh

function print_usage {
    echo "Usage: generate-hivemr3-ssl.sh [option(s)]"
    echo " --validity <valDays>                   Specifies the number of days for which the certificate \
should be considered valid."
    echo ""
}

function parse_args {
    VALID_DAYS=365

    while [ "${1+defined}" ]; do
      case "$1" in
        -h|--help)
          print_usage
          exit 1
          ;;
        --validity)
          VALID_DAYS=$2
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
}

function check_if_output_files_already_exist {
    output_files="$MR3_SSL_KEYSTORE $MR3_SSL_CREDENTIAL_PROVIDER $MR3_SSL_CREDENTIAL_PROVIDER_CHECKSUM"
    for output_file in $output_files; do
      if [ -e $output_file ]; then
        echo -e "\n$output_file already exists" >&2
        exit 1;
      fi
    done
}

function generate_keystore_password {
    PASSWORD=$(cat /proc/sys/kernel/random/uuid)
    export HADOOP_CREDSTORE_PASSWORD=$PASSWORD
    echo -e "Generated keystore password: $PASSWORD" >&2
}

function generate_subject_alternative_name {
    declare -A host_to_service

    if [ ! -z $HIVE_SERVER2_HOST ]; then
      host_to_service[$HIVE_SERVER2_HOST]="${host_to_service[$HIVE_SERVER2_HOST]} HiveServer2"
    fi 
    if [ ! -z $RANGER_HOST ]; then
      host_to_service[$RANGER_HOST]="${host_to_service[$RANGER_HOST]} Ranger"
    fi 
    if [ ! -z $ATS_HOST ]; then
      host_to_service[$ATS_HOST]="${host_to_service[$ATS_HOST]} TimelineServer"
    fi 
    if [ ! -z $HIVE_METASTORE_HOST ]; then
      host_to_service[$HIVE_METASTORE_HOST]="${host_to_service[$HIVE_METASTORE_HOST]} Metastore"
    fi
    if [ ! -z $KMS_HOST ]; then
      host_to_service[$KMS_HOST]="${host_to_service[$KMS_HOST]} KMS"
    fi
    if [ ! -z $MYSQL_HOST ]; then
      host_to_service[$MYSQL_HOST]="${host_to_service[$MYSQL_HOST]} MySQL"
    fi

    echo -e "Hosts to add to the certificate to generate:" >&2
    for host in ${!host_to_service[@]}; do
      echo -e " $host:${host_to_service[$host]}"
    done

    SUBJECT_ALTERNATIVE_NAME=""
    for host in ${!host_to_service[@]}; do
      SUBJECT_ALTERNATIVE_NAME="$SUBJECT_ALTERNATIVE_NAME,DNS:$host"
    done
    SUBJECT_ALTERNATIVE_NAME=${SUBJECT_ALTERNATIVE_NAME:1}
}

function init {
    generate_keystore_password
    generate_subject_alternative_name
}

function generate_keystore {
    echo -e "\n# Generating a keystore ($MR3_SSL_KEYSTORE) #" >&2

    keytool -genkeypair -alias ssl-private-key -keyalg RSA -dname "CN=red0" -keypass $PASSWORD \
      -ext san=$SUBJECT_ALTERNATIVE_NAME -validity $VALID_DAYS -storetype jks -keystore $MR3_SSL_KEYSTORE \
      -storepass $PASSWORD
}

function generate_keystore_credential_file {
    echo -e "\n# Generating a credential file ($MR3_SSL_CREDENTIAL_PROVIDER) #" >&2

    entries="ssl.server.keystore.password ssl.server.truststore.password ssl.server.keystore.keypassword \
ssl.client.truststore.password \
keyStoreAlias trustStoreAlias keyStoreCredentialAlias sslKeyStore sslTrustStore \
solr.jetty.keystore.password solr.jetty.truststore.password \
hive.server2.keystore.password hive.metastore.keystore.password hive.metastore.truststore.password"
    for entry in $entries; do
      $HADOOP_HOME_LOCAL/bin/hadoop credential create $entry \
        -provider jceks://file/$MR3_SSL_CREDENTIAL_PROVIDER \
        -value $PASSWORD
    done
}

function main {
    parse_args $@

    check_if_output_files_already_exist
    init
    generate_keystore
    generate_keystore_credential_file
    unset HADOOP_CREDSTORE_PASSWORD
}

main $@
