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
# All settings which should be consistent with hive/Dockerfile, yaml/hive.yaml, and run-hive.sh.
#

#
# Basic settings
# 

REMOTE_BASE_DIR=/opt/mr3-run
REMOTE_WORK_DIR=$REMOTE_BASE_DIR/hive
CONF_DIR_MOUNT_DIR=$REMOTE_BASE_DIR/conf
# for mr3.k8s.keytab.mount.dir
KEYTAB_MOUNT_DIR=$REMOTE_BASE_DIR/key
WORK_DIR_PERSISTENT_VOLUME_CLAIM=workdir-pvc
WORK_DIR_PERSISTENT_VOLUME_CLAIM_MOUNT_DIR=/opt/mr3-run/work-dir

# JAVA_HOME and PATH are already set inside the container.

# If USE_JAVA_17 is set to false,
#
#   1) update mr3.am.launch.cmd-opts and mr3.container.launch.cmd-opts in conf/mr3-site.xml.
#     add: -XX:+AggressiveOpts
#
# Cf. run-master.sh and run-worker.sh set "--add-opens".
#
export USE_JAVA_17=true

# HIVE_MR3_JVM_OPTION = JVM options for Metastore and HiveServer2
if [[ $USE_JAVA_17 = false ]]; then
  HIVE_MR3_JVM_OPTION="-XX:+UseG1GC -XX:+ResizeTLAB -XX:+UseNUMA -server -Djava.net.preferIPv4Stack=true -XX:+AggressiveOpts"
else
  HIVE_MR3_JVM_OPTION="-XX:+UseG1GC -XX:+ResizeTLAB -XX:+UseNUMA -server -Djava.net.preferIPv4Stack=true"
  HIVE_MR3_JVM_OPTION="$HIVE_MR3_JVM_OPTION --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.net=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.time=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.util.concurrent=ALL-UNNAMED --add-opens java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens java.base/java.util.regex=ALL-UNNAMED --add-opens java.base/java.util.zip=ALL-UNNAMED --add-opens java.base/java.util.stream=ALL-UNNAMED --add-opens java.base/java.util.jar=ALL-UNNAMED --add-opens java.base/java.util.function=ALL-UNNAMED --add-opens java.logging/java.util.logging=ALL-UNNAMED --add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/java.lang.reflect=ALL-UNNAMED --add-opens java.base/java.lang.ref=ALL-UNNAMED --add-opens java.base/java.nio.charset=ALL-UNNAMED --add-opens java.base/java.text=ALL-UNNAMED --add-opens java.base/java.util.concurrent.locks=ALL-UNNAMED --add-opens java.base/sun.util.calendar=ALL-UNNAMED"
fi

# If hive.mr3.compaction.using.mr3 in conf/hive-site.xml is set to true, Metastore needs a PersistentVolume.
# See spec.template.spec.containers.volumeMounts/volumes in yaml/metastore.yaml and helm/hive/templates/metastore.yaml.
# metastore.mountLib in helm/hive/values.yaml should be set to true to mount the MySQL connector provided by the user.
METASTORE_USE_PERSISTENT_VOLUME=true

# set to true on AWS EKS if a workdir PVC is pre-created
RUN_AWS_EKS=false

CREATE_SERVICE_ACCOUNTS=true

#
# Step 1. Building a Docker image
#

DOCKER_HIVE_IMG=${DOCKER_HIVE_IMG:-mr3project/hive3:1.10}
DOCKER_HIVE_FILE=${DOCKER_HIVE_FILE:-Dockerfile}

DOCKER_HIVE_WORKER_IMG=${DOCKER_HIVE_WORKER_IMG:-mr3project/hive3:1.10}
DOCKER_HIVE_WORKER_FILE=${DOCKER_HIVE_WORKER_FILE:-Dockerfile-worker}

DOCKER_RANGER_IMG=mr3project/ranger:2.4.0
DOCKER_RANGER_FILE=Dockerfile

DOCKER_ATS_IMG=mr3project/mr3ui:1.5
DOCKER_ATS_FILE=Dockerfile

DOCKER_SUPERSET_IMG=mr3project/superset:1.3.2
DOCKER_SUPERSET_FILE=Dockerfile

DOCKER_APACHE_IMG=mr3project/httpd:2.4
DOCKER_APACHE_FILE=Dockerfile

# do not use a composite name like hive@RED, hive/red0@RED (which results in NPE in ContainerWorker)
DOCKER_USER=hive

#
# Step 2. Configuring Pods
#

MR3_NAMESPACE=hivemr3
MR3_SERVICE_ACCOUNT=hive-service-account
CONF_DIR_CONFIGMAP=hivemr3-conf-configmap

MASTER_SERVICE_ACCOUNT=master-service-account
WORKER_SERVICE_ACCOUNT=worker-service-account

# CREATE_KEYTAB_SECRET specifies whether or not to create a Secret from key/*.
# CREATE_KEYTAB_SECRET should be set to true if any of the following holds:
#   1) TOKEN_RENEWAL_HDFS_ENABLED=true
#   2) TOKEN_RENEWAL_HIVE_ENABLED=true
#   3) SSL is enabled
CREATE_KEYTAB_SECRET=false
KEYTAB_SECRET=hivemr3-keytab-secret

# CREATE_WORKER_SECRET specifies whether or not to create a Secret for ContainerWorkers from $WORKER_SECRET_DIR.
# CREATE_WORKER_SECRET is irrelevant to token renewal, and WORKER_SECRET_DIR is not requird to contain keytab files.
# CREATE_WORKER_SECRET should be set to true if:
#   - SSL is enabled
CREATE_WORKER_SECRET=false
WORKER_SECRET_DIR=$BASE_DIR/key/       # can be set to '$BASEDIR/workersecret/'
WORKER_SECRET=hivemr3-worker-secret

CREATE_RANGER_SECRET=true   # specifies whether or not to create a Secret from ranger-key/*
CREATE_ATS_SECRET=true      # specifies whether or not to create a Secret from ats-key/*
CREATE_TIMELINE_SECRET=true # specifies whether or not to create a Secret from timeline-key/*


#
# Step 3. Update YAML files
#

#
# Step 4. Configuring HiveServer2 - connecting to Metastore
#

# HIVE_DATABASE_HOST = host for Metastore database 
# HIVE_METASTORE_HOST = host for Metastore itself 
# HIVE_METASTORE_PORT = port for Hive Metastore 
# HIVE_DATABASE_NAME = database name in Hive Metastore 
# HIVE_WAREHOUSE_DIR = directory for the Hive warehouse 

HIVE_DATABASE_HOST=1.1.1.1

# if an existing Metastore is used 
# HIVE_METASTORE_HOST=red0
# if a new Metastore Pod is to be created inside K8s
HIVE_METASTORE_HOST=hivemr3-metastore-0.metastore.hivemr3.svc.cluster.local

HIVE_METASTORE_PORT=9850
HIVE_DATABASE_NAME=hive3mr3

# path to the data warehouse, e.g.,
#   hdfs://foo:8020/user/hive/warehouse
#   s3a://mr3-bucket/warehouse
#   /opt/mr3-run/work-dir/warehouse/
HIVE_WAREHOUSE_DIR=/opt/mr3-run/work-dir/warehouse/

# Specifies hive.metastore.sasl.enabled 
METASTORE_SECURE_MODE=false

# For security in Metastore 
# Kerberos principal for Metastore; cf. 'hive.metastore.kerberos.principal' in hive-site.xml
HIVE_METASTORE_KERBEROS_PRINCIPAL=hive/red0@RED
# Kerberos keytab for Metastore; cf. 'hive.metastore.kerberos.keytab.file' in hive-site.xml
HIVE_METASTORE_KERBEROS_KEYTAB=$KEYTAB_MOUNT_DIR/hive-admin.keytab

#
# Step 5. Configuring HiveServer2 - connecting to HiveServer2
#

# HIVE_SERVER2_PORT = thrift port for HiveServer2 (for both cluster mode and local mode)
# HIVE_SERVER2_HTTP_PORT = http port for HiveServer2
#
HIVE_SERVER2_HOST=$HOSTNAME
HIVE_SERVER2_PORT=9852
HIVE_SERVER2_HTTP_PORT=10001

# Heap size in MB for HiveServer2
# With --local option, mr3.am.resource.memory.mb and mr3.am.local.resourcescheduler.max.memory.mb should be smaller. 
# should not exceed than the resource limit specified in yaml/hive.yaml
HIVE_SERVER2_HEAPSIZE=16384

# For security in HiveServer2 
# Beeline should also provide this Kerberos principal.
# Authentication option: NONE (uses plain SASL), NOSASL, KERBEROS, LDAP, PAM, and CUSTOM; cf. 'hive.server2.authentication' in hive-site.xml 
HIVE_SERVER2_AUTHENTICATION=NONE
# Kerberos principal for HiveServer2; cf. 'hive.server2.authentication.kerberos.principal' in hive-site.xml 
HIVE_SERVER2_KERBEROS_PRINCIPAL=hive/red0@RED
# Kerberos keytab for HiveServer2; cf. 'hive.server2.authentication.kerberos.keytab' in hive-site.xml 
HIVE_SERVER2_KERBEROS_KEYTAB=$KEYTAB_MOUNT_DIR/hive-admin.keytab

# Specifies whether Hive token renewal is enabled inside DAGAppMaster and ContainerWorkers 
TOKEN_RENEWAL_HIVE_ENABLED=false

# Truststore for HiveServer2
# For Timeline Server, Ranger, see their configuration files
HIVE_SERVER2_SSL_TRUSTSTORE=$KEYTAB_MOUNT_DIR/hivemr3-ssl-certificate.jks
HIVE_SERVER2_SSL_TRUSTSTORETYPE=jks
HIVE_SERVER2_SSL_TRUSTSTOREPASS=
export HADOOP_CREDSTORE_PASSWORD=

#
# Step 6. Reading from a secure HDFS
#

# 1) for renewing HDFS/Hive tokens in DAGAppMaster (mr3.keytab in mr3-site.xml)
# 2) for renewing HDFS/Hive tokens in ContainerWorker (mr3.k8s.keytab.mount.file in mr3-site.xml)

# Kerberos principal for renewing HDFS/Hive tokens (for mr3.principal)
USER_PRINCIPAL=hive@RED
# Kerberos keytab (for mr3.keytab)
USER_KEYTAB=$KEYTAB_MOUNT_DIR/hive.keytab
# for mr3.k8s.keytab.mount.file
KEYTAB_MOUNT_FILE=hive.keytab

# Specifies whether HDFS token renewal is enabled inside DAGAppMaster and ContainerWorkers 
TOKEN_RENEWAL_HDFS_ENABLED=false

#
# Step 7. Additional settings
#

CREATE_PROMETHEUS_SERVICE=false

# Logging level 
# TODO: Currently LOG_LEVEL does not update the logging level of MR3.
# To change the logging level of Hive, update conf/hive-log4j2.properties (for Hive 2+).
LOG_LEVEL=INFO

#
# Additional environment variables for HiveServer2 and Metastore
#
# Here the user can define additional environment variables using 'EXPORT', e.g.:
#   export FOO=bar
#

#
# For running Metastore
#

# Heap size in MB for Metastore
# should not exceed the resource limit specified in yaml/metastore.yaml
HIVE_METASTORE_HEAPSIZE=16384

# Type of Metastore database which is used when running 'schematool -initSchema'
HIVE_METASTORE_DB_TYPE=mysql

#
# For running HiveCLI 
#

# Heap size in MB for HiveCLI ('hive' command) 
# With --local option, mr3.am.resource.memory.mb and mr3.am.local.resourcescheduler.max.memory.mb should be smaller. 
HIVE_CLIENT_HEAPSIZE=16384

#
# For running Timeline Server 
#

# unset because 'hive' command reads SPARK_HOME and may accidentally expand the classpath with HiveConf.class from Spark. 
# SPARK_HOME is automatically set by spark-setup.sh if Spark-MR3 is executed
unset SPARK_HOME

