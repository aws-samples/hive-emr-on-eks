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

#
# Configuring SSL
#

ENABLE_SSL=false
ENABLE_SSL_RANGER=false

# If ENABLE_SSL/ENABLE_SSL_RANGER is set to true, run-hive.sh, run-ats.sh, and run-ranger.sh create the following files
# and copy them to key/, ats-key/, and ranger-key/, respectively:
#   hivemr3-ssl-certificate.jceks
#   hivemr3-ssl-certificate.jks
#   .hivemr3-ssl-certificate.jceks.crc

#
# For generating a self-signed certificate in MR3_SSL_KEYSTORE with generate-hivemr3-ssl.sh
#

# Keystore file for MR3 components (HiveServer2, Timeline Server, Ranger, Metastore)
# The administrator can extract a certificate from this keystore file and distribute it to users.
MR3_SSL_KEYSTORE=/home/hive/mr3-run/kubernetes/mr3-ssl.jks
MR3_SSL_CREDENTIAL_PROVIDER=/home/hive/mr3-run/kubernetes/mr3-ssl.jceks
MR3_SSL_CREDENTIAL_PROVIDER_CHECKSUM=/home/hive/mr3-run/kubernetes/.mr3-ssl.jceks.crc

# Host names for HiveServer2 Service, Ranger Service, Timeline Server Service, and MySQL
HIVE_SERVER2_HOST=red0
ATS_HOST=red0
RANGER_HOST=red0
HIVE_METASTORE_HOST=hivemr3-metastore-0.metastore.hivemr3.svc.cluster.local
KMS_HOST=red0
MYSQL_HOST=red0

# Set to the password after executing generate-hivemr3-ssl.sh
MR3_SSL_KEYSTORE_PASSWORD=80d4163f-9798-4786-938a-50dadf7c86af

# Certificate for connecting to MySQL for Ranger server
MR3_RANGER_MYSQL_CERTIFICATE=/home/hive/mr3-run/kubernetes/mr3-ranger-mysql.cert
# Certificate for connecting to MySQL for Metastore (or Metastore itself)
MR3_METASTORE_MYSQL_CERTIFICATE=/home/hive/mr3-run/kubernetes/mr3-metastore.cert
# Certificate for connecting to KMS
MR3_KMS_CERTIFICATE=/home/hive/mr3-run/kubernetes/mr3-kms.cert
# Certificate for connecting to S3
MR3_S3_CERTIFICATE=/home/hive/mr3-run/kubernetes/s3-public.cert

#
# create_hivemr3_ssl_certificate()
#

function check_destination_directory {
    dest_dir=$1

    echo -e "\nCreating MR3 SSL certificates..." >&2
    if [ -z $dest_dir ]; then
      echo -e "\nDestination directory must be nonempty" >&2
      exit 1;
    fi
    if [ ! -d $dest_dir ]; then
      echo -e "\n$dest_dir is not a directory" >&2
      exit 1;
    fi
}

function import_certificate {
    keystore=$1
    certificate=$2
    alias=$3

    echo -e "\nImporting $certificate..." >&2
    keytool -importcert -alias $alias -file $certificate -noprompt -storetype jks -keystore $keystore \
      -storepass $MR3_SSL_KEYSTORE_PASSWORD
}

function import_certificates {
    keystore=$1

    certificates="$MR3_RANGER_MYSQL_CERTIFICATE $MR3_METASTORE_MYSQL_CERTIFICATE $MR3_KMS_CERTIFICATE $MR3_S3_CERTIFICATE"
    index=0
    for certificate in $certificates; do
      if [ -f $certificate ]; then
        alias=trusted-cert-$index
        import_certificate $keystore $certificate $alias
        index=$(($index + 1))
      fi
    done
}

function create_hivemr3_ssl_certificate {
    dest_dir=$1

    dest_keystore=$dest_dir/hivemr3-ssl-certificate.jks
    dest_credential_provider=$dest_dir/hivemr3-ssl-certificate.jceks
    dest_credential_provider_checksum=$dest_dir/.hivemr3-ssl-certificate.jceks.crc

    check_destination_directory $dest_dir
    cp $MR3_SSL_KEYSTORE $dest_keystore
    cp $MR3_SSL_CREDENTIAL_PROVIDER $dest_credential_provider
    cp $MR3_SSL_CREDENTIAL_PROVIDER_CHECKSUM $dest_credential_provider_checksum
    import_certificates $dest_keystore
}

function create_sparkmr3_ssl_certificate {
    dest_dir=$1

    dest_keystore=$dest_dir/sparkmr3-ssl-certificate.jks
    dest_credential_provider=$dest_dir/sparkmr3-ssl-certificate.jceks
    dest_credential_provider_checksum=$dest_dir/.sparkmr3-ssl-certificate.jceks.crc

    check_destination_directory $dest_dir
    cp $MR3_SSL_KEYSTORE $dest_keystore
    cp $MR3_SSL_CREDENTIAL_PROVIDER $dest_credential_provider
    cp $MR3_SSL_CREDENTIAL_PROVIDER_CHECKSUM $dest_credential_provider_checksum
    import_certificates $dest_keystore
}

#
# run_kubernetes_parse_args ()
#

function run_kubernetes_parse_args {
    while [ "${1+defined}" ]; do
        case "$1" in
            --generate-truststore)
                export GENERATE_TRUSTSTORE_ONLY=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

