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

function setup_ranger() {
    export RANGER_ADMIN_CONF=/opt/mr3-run/ranger/key  # now we use /opt/mr3-run/ranger/key/install.properties

    cp /opt/mr3-run/ranger/conf/krb5.conf /etc/krb5.conf

    pushd $BASE_DIR/ranger-admin > /dev/null

    # Read install.properties to update ranger-admin-site.xml and ranger-admin-default-site.xml
    # in /opt/mr3-run/ranger/ranger-admin/ews/webapp/WEB-INF/classes/conf
    #
    # Thus we need to set configurations only in install.properties.
    ./setup.sh

    # Remove ranger.solr.audit.user and ranger.solr.audit.user.password
    #
    # If ranger.solr.audit.user/ranger.solr.audit.user.password are defined (even with empty values),
    # Kerberos authenticaion is not used.
    # This should be executed even when Kerberos authenticaion is not used.
    sed -i 's/ranger.solr.audit.user/DO.NOT.USE.ranger.solr.audit.user/g' conf/ranger-admin-site.xml

    # Append conf/ranger-admin-site.xml.append to conf/ranger-admin-site.xml
    #
    # This step is necessary because ranger-admin-site.xml created from install.properties is missing some keys.
    sed -i '/<\/configuration>/ r /opt/mr3-run/ranger/conf/ranger-admin-site.xml.append' conf/ranger-admin-site.xml
    sed -i '0,/<\/configuration>/{/<\/configuration>/d}' conf/ranger-admin-site.xml

    popd > /dev/null

    cp $BASE_DIR/conf/ranger-log4j.properties $BASE_DIR/ranger-admin/ews/webapp/WEB-INF/log4j.properties

    # Dummy HADOOP_HOME prevents an error while org.apache.hadoop.util.Shell
    # initializes its static vairable.
    export HADOOP_HOME=/
}

function start_ranger {
    $BASE_DIR/ranger-admin/ews/ranger-admin-services.sh start
    sleep infinity
}

function main {
    pushd /opt/mr3-run/lib
    wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-8.0.28.tar.gz
    tar --strip-components=1 -zxf mysql-connector-java-8.0.28.tar.gz mysql-connector-java-8.0.28/mysql-connector-java-8.0.28.jar
    rm -f mysql-connector-java-8.0.28.tar.gz
    popd

    setup_ranger
    start_ranger
}

main $@
