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
# Basic settings
# 

REMOTE_BASE_DIR={{.Values.dir.base}}
REMOTE_WORK_DIR={{.Values.dir.work}}
CONF_DIR_MOUNT_DIR={{.Values.dir.conf}}
# for mr3.k8s.keytab.mount.dir
KEYTAB_MOUNT_DIR={{.Values.dir.keytab}}
WORK_DIR_PERSISTENT_VOLUME_CLAIM={{.Values.name.persistentVolumeClaim}}
WORK_DIR_PERSISTENT_VOLUME_CLAIM_MOUNT_DIR={{.Values.dir.persistentVolumeClaim}}

# JAVA_HOME and PATH are already set inside the container.

# If USE_JAVA_17 is set to false,
#
#   1) update mr3.am.launch.cmd-opts and mr3.container.launch.cmd-opts in conf/mr3-site.xml.
#     remove: -XX:+AggressiveOpts
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

#
# Step 1. Building a Docker image
#

DOCKER_HIVE_IMG={{.Values.docker.image}}
DOCKER_HIVE_WORKER_IMG={{.Values.docker.containerWorkerImage}}

DOCKER_USER={{.Values.docker.user}}

#
# Step 2. Configuring Pods
#

MR3_NAMESPACE={{.Release.Namespace}}
MR3_SERVICE_ACCOUNT={{.Values.name.hive.serviceAccount}}
CONF_DIR_CONFIGMAP={{.Values.name.hive.configMap}}

MASTER_SERVICE_ACCOUNT={{.Values.name.mr3.masterServiceAccount}}
WORKER_SERVICE_ACCOUNT={{.Values.name.mr3.workerServiceAccount}}

# CREATE_KEYTAB_SECRET specifies whether or not to create a Secret from key/*.
# CREATE_KEYTAB_SECRET should be set to true if any of the following holds:
#   1) TOKEN_RENEWAL_HDFS_ENABLED=true
#   2) TOKEN_RENEWAL_HIVE_ENABLED=true
#   3) SSL is enabled
CREATE_KEYTAB_SECRET={{.Values.hive.createSecret}}
KEYTAB_SECRET={{.Values.name.hive.secret}}

# CREATE_WORKER_SECRET specifies whether or not to create a Secret for ContainerWorkers from $WORKER_SECRET_DIR.
# CREATE_WORKER_SECRET is irrelevant to token renewal, and WORKER_SECRET_DIR is not requird to contain keytab files.
# CREATE_WORKER_SECRET should be set to true if:
#   - SSL is enabled
CREATE_WORKER_SECRET={{.Values.hive.createSecret}}
WORKER_SECRET={{.Values.name.hive.workerSecret}}

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

HIVE_DATABASE_HOST={{.Values.metastore.databaseHost}}

# if an existing Metastore is used 
# HIVE_METASTORE_HOST=red0
# if a new Metastore Pod is to be created inside K8s
HIVE_METASTORE_HOST={{if .Values.create.metastore}}hivemr3-metastore-0.metastore.{{.Release.Namespace}}.svc.cluster.local {{- else}}{{.Values.metastore.host}}{{end}}

HIVE_METASTORE_PORT={{.Values.metastore.port}}
HIVE_DATABASE_NAME={{.Values.metastore.databaseName}}

# path to the data warehouse, e.g.,
#   hdfs://foo:8020/user/hive/warehouse
#   s3a://mr3-bucket/warehouse
#   /opt/mr3-run/work-dir/warehouse/
HIVE_WAREHOUSE_DIR={{.Values.metastore.warehouseDir}}

# Specifies hive.metastore.sasl.enabled 
METASTORE_SECURE_MODE={{.Values.metastore.secureMode}}

# For security in Metastore 
# Kerberos principal for Metastore; cf. 'hive.metastore.kerberos.principal' in hive-site.xml
HIVE_METASTORE_KERBEROS_PRINCIPAL={{.Values.metastore.kerberosPrincipal}}
# Kerberos keytab for Metastore; cf. 'hive.metastore.kerberos.keytab.file' in hive-site.xml
HIVE_METASTORE_KERBEROS_KEYTAB=$KEYTAB_MOUNT_DIR/{{.Values.metastore.kerberosKeytab}}

#
# Step 5. Configuring HiveServer2 - connecting to HiveServer2
#

# HIVE_SERVER2_PORT = thrift port for HiveServer2 (for both cluster mode and local mode)
# HIVE_SERVER2_HTTP_PORT = http port for HiveServer2
#
HIVE_SERVER2_HOST=$HOSTNAME
HIVE_SERVER2_PORT={{.Values.hive.port}}
HIVE_SERVER2_HTTP_PORT={{.Values.hive.httpport}}

# Heap size in MB for HiveServer2
# With --local option, mr3.am.resource.memory.mb and mr3.am.local.resourcescheduler.max.memory.mb should be smaller. 
HIVE_SERVER2_HEAPSIZE={{.Values.hive.heapSize}}

# For security in HiveServer2 
# Beeline should also provide this Kerberos principal.
# Authentication option: NONE (uses plain SASL), NOSASL, KERBEROS, LDAP, PAM, and CUSTOM; cf. 'hive.server2.authentication' in hive-site.xml 
HIVE_SERVER2_AUTHENTICATION={{.Values.hive.authentication}}
# Kerberos principal for HiveServer2; cf. 'hive.server2.authentication.kerberos.principal' in hive-site.xml 
HIVE_SERVER2_KERBEROS_PRINCIPAL={{.Values.hive.kerberosPrincipal}}
# Kerberos keytab for HiveServer2; cf. 'hive.server2.authentication.kerberos.keytab' in hive-site.xml 
HIVE_SERVER2_KERBEROS_KEYTAB=$KEYTAB_MOUNT_DIR/{{.Values.hive.kerberosKeytab}}

# Specifies whether Hive token renewal is enabled inside DAGAppMaster and ContainerWorkers 
TOKEN_RENEWAL_HIVE_ENABLED={{.Values.hive.tokenRenewalEnabled}}

# Truststore for HiveServer2
# For Timeline Server, Ranger, see their configuration files
HIVE_SERVER2_SSL_TRUSTSTORE=$KEYTAB_MOUNT_DIR/{{.Values.hive.sslTruststore}}
HIVE_SERVER2_SSL_TRUSTSTORETYPE={{.Values.hive.sslTruststoreType}}

#
# Step 6. Reading from a secure HDFS
#

# 1) for renewing HDFS/Hive tokens in DAGAppMaster (mr3.keytab in mr3-site.xml)
# 2) for renewing HDFS/Hive tokens in ContainerWorker (mr3.k8s.keytab.mount.file in mr3-site.xml)

# Kerberos principal for renewing HDFS/Hive tokens (Cf. mr3.principal)
USER_PRINCIPAL={{.Values.hdfs.userPrincipal}}
# Kerberos keytab (for mr3.keytab)
USER_KEYTAB=$KEYTAB_MOUNT_DIR/{{.Values.hdfs.userKeytab}}
# for mr3.k8s.keytab.mount.file
KEYTAB_MOUNT_FILE={{.Values.hdfs.userKeytab}}

# Specifies whether HDFS token renewal is enabled inside DAGAppMaster and ContainerWorkers 
TOKEN_RENEWAL_HDFS_ENABLED={{.Values.hdfs.tokenRenewalEnabled}}

#
# Step 7. Additional settings
#

# Logging level 
LOG_LEVEL={{.Values.logLevel}}

#
# For running Metastore
#

# Heap size in MB for Metastore
HIVE_METASTORE_HEAPSIZE={{.Values.metastore.heapSize}}

# Type of Metastore database which is used when running 'schematool -initSchema'
HIVE_METASTORE_DB_TYPE={{.Values.metastore.dbType}}

#
# For running HiveCLI 
#

# Heap size in MB for HiveCLI ('hive' command) 
# With --local option, mr3.am.resource.memory.mb and mr3.am.local.resourcescheduler.max.memory.mb should be smaller. 
HIVE_CLIENT_HEAPSIZE=16384

# unset because 'hive' command reads SPARK_HOME and may accidentally expand the classpath with HiveConf.class from Spark. 
unset SPARK_HOME

