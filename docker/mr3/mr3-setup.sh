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

function mr3_setup_init {
    MR3_LIB_DIR=$MR3_BASE_DIR/mr3lib
    MR3_CLASSPATH=$MR3_LIB_DIR/*
}

function mr3_setup_update_hadoop_opts {
    local_mode=$1

    MR3_KUBERNETES_OPTS="-Dmr3.k8s.namespace=$MR3_NAMESPACE \
-Dmr3.k8s.pod.master.serviceaccount=$MASTER_SERVICE_ACCOUNT \
-Dmr3.k8s.pod.worker.serviceaccount=$WORKER_SERVICE_ACCOUNT \
-Dmr3.k8s.pod.master.image=$DOCKER_HIVE_IMG \
-Dmr3.k8s.pod.worker.image=$DOCKER_HIVE_WORKER_IMG \
-Dmr3.k8s.pod.master.user=$DOCKER_USER -Dmr3.k8s.master.working.dir=$REMOTE_WORK_DIR \
-Dmr3.k8s.pod.worker.user=$DOCKER_USER -Dmr3.k8s.worker.working.dir=$REMOTE_WORK_DIR \
-Dmr3.k8s.java.io.tmpdir=$REMOTE_WORK_DIR/tmp \
-Dmr3.k8s.conf.dir.configmap=$CONF_DIR_CONFIGMAP -Dmr3.k8s.conf.dir.mount.dir=$CONF_DIR_MOUNT_DIR \
-Dmr3.k8s.keytab.secret=$KEYTAB_SECRET \
-Dmr3.k8s.worker.secret=$WORKER_SECRET \
-Dmr3.k8s.mount.keytab.secret=$CREATE_KEYTAB_SECRET \
-Dmr3.k8s.mount.worker.secret=$CREATE_WORKER_SECRET \
-Dmr3.k8s.keytab.mount.dir=$KEYTAB_MOUNT_DIR -Dmr3.k8s.keytab.mount.file=$KEYTAB_MOUNT_FILE \
-Dmr3.k8s.master.persistentvolumeclaim.mounts=$WORK_DIR_PERSISTENT_VOLUME_CLAIM=$WORK_DIR_PERSISTENT_VOLUME_CLAIM_MOUNT_DIR \
-Dmr3.k8s.worker.persistentvolumeclaim.mounts=$WORK_DIR_PERSISTENT_VOLUME_CLAIM=$WORK_DIR_PERSISTENT_VOLUME_CLAIM_MOUNT_DIR"
    export HADOOP_OPTS="$HADOOP_OPTS $MR3_KUBERNETES_OPTS" 

    export HADOOP_OPTS="$HADOOP_OPTS -Dmr3.master.mode=$local_mode"

    # include mr3jar/lib first because of some classes overriden in Tez (e.g., TezCounters)
    MR3_ADD_CLASSPATH_OPTS="-Dmr3.cluster.additional.classpath=$REMOTE_BASE_DIR/mr3/mr3lib/*:$REMOTE_BASE_DIR/hive/apache-hive/lib/*:$REMOTE_BASE_DIR/tez/tezjar/*:$REMOTE_BASE_DIR/tez/tezjar/lib/*"
    export HADOOP_OPTS="$HADOOP_OPTS $MR3_ADD_CLASSPATH_OPTS" 

    if [[ $TOKEN_RENEWAL_HDFS_ENABLED = "true" ]] || [[ $TOKEN_RENEWAL_HIVE_ENABLED = "true" ]]; then
        export HADOOP_OPTS="$HADOOP_OPTS -Dmr3.principal=$USER_PRINCIPAL -Dmr3.keytab=$USER_KEYTAB"
    fi
    if [[ $TOKEN_RENEWAL_HDFS_ENABLED = "true" ]]; then
        export HADOOP_OPTS="$HADOOP_OPTS -Dmr3.token.renewal.hdfs.enabled=true"
    fi
    if [[ $TOKEN_RENEWAL_HIVE_ENABLED = "true" ]]; then
        export HADOOP_OPTS="$HADOOP_OPTS -Dmr3.token.renewal.hive.enabled=true"
    fi

    # -Dmr3.XXX=YYY directly adds (mr3.XXX -> YYY) to MR3Conf
    # Thus, mr3-setup.sh always sets mr3.am.log.level and mr3.container.log.level 
    MR3_LOG_OPTS="-Dmr3.am.log.level=$LOG_LEVEL -Dmr3.container.log.level=$LOG_LEVEL"
    export HADOOP_OPTS="$HADOOP_OPTS $MR3_LOG_OPTS"
}

