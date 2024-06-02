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
YAML_DIR=$BASE_DIR/yaml

source $BASE_DIR/config-run.sh
source $BASE_DIR/env.sh 

if [ $ENABLE_SSL = true ]; then
  create_hivemr3_ssl_certificate $BASE_DIR/key
fi

# run as the user who has set up ~/.kube/config

kubectl create namespace $MR3_NAMESPACE

if [ $METASTORE_USE_PERSISTENT_VOLUME = true ]; then
  if [ $RUN_AWS_EKS = true ]; then
    echo "assume that PersistentVolumeClaim workdir-pvc has been created"
  else
    kubectl create -f $YAML_DIR/workdir-pv.yaml 
    kubectl create -n $MR3_NAMESPACE -f $YAML_DIR/workdir-pvc.yaml 
  fi
fi

kubectl create -n $MR3_NAMESPACE secret generic env-secret --from-file=$BASE_DIR/env.sh
kubectl create -n $MR3_NAMESPACE configmap $CONF_DIR_CONFIGMAP --from-file=$BASE_DIR/conf/

if [ $CREATE_KEYTAB_SECRET = true ]; then
  kubectl create -n $MR3_NAMESPACE secret generic $KEYTAB_SECRET --from-file=$BASE_DIR/key/
else 
  kubectl create -n $MR3_NAMESPACE secret generic $KEYTAB_SECRET
fi

if [ $CREATE_WORKER_SECRET = true ]; then
  kubectl create -n $MR3_NAMESPACE secret generic $WORKER_SECRET --from-file=$WORKER_SECRET_DIR
else 
  kubectl create -n $MR3_NAMESPACE secret generic $WORKER_SECRET
fi

kubectl create -f $YAML_DIR/cluster-role.yaml
kubectl create -f $YAML_DIR/hive-role.yaml
if [ $CREATE_SERVICE_ACCOUNTS = true ]; then
  kubectl create -f $YAML_DIR/hive-service-account.yaml
fi

kubectl create clusterrolebinding hive-clusterrole-binding --clusterrole=node-reader --serviceaccount=$MR3_NAMESPACE:$MR3_SERVICE_ACCOUNT
kubectl create rolebinding hive-role-binding --role=hive-role --serviceaccount=$MR3_NAMESPACE:$MR3_SERVICE_ACCOUNT -n $MR3_NAMESPACE

# reuse CLIENT_TO_AM_TOKEN_KEY if already defined; use a random UUID otherwise
RANDOM_CLIENT_TO_AM_TOKEN_KEY=$(cat /proc/sys/kernel/random/uuid)
CLIENT_TO_AM_TOKEN_KEY=${CLIENT_TO_AM_TOKEN_KEY:-$RANDOM_CLIENT_TO_AM_TOKEN_KEY}
echo "CLIENT_TO_AM_TOKEN_KEY=$CLIENT_TO_AM_TOKEN_KEY"

# reuse MR3_APPLICATION_ID_TIMESTAMP if already defined; use a random integer > 0
RANDOM_MR3_APPLICATION_ID_TIMESTAMP=$RANDOM
MR3_APPLICATION_ID_TIMESTAMP=${MR3_APPLICATION_ID_TIMESTAMP:-$RANDOM_MR3_APPLICATION_ID_TIMESTAMP}
echo "MR3_APPLICATION_ID_TIMESTAMP=$MR3_APPLICATION_ID_TIMESTAMP"

# reuse MR3_SHARED_SESSION_ID if already defined; use a random UUID otherwise
RANDOM_MR3_SHARED_SESSION_ID=$(cat /proc/sys/kernel/random/uuid)
MR3_SHARED_SESSION_ID=${MR3_SHARED_SESSION_ID:-$RANDOM_MR3_SHARED_SESSION_ID}
echo "MR3_SHARED_SESSION_ID=$MR3_SHARED_SESSION_ID"

# reuse ATS_SECRET_KEY if already defined; use a random UUID otherwise
RANDOM_ATS_SECRET_KEY=$(cat /proc/sys/kernel/random/uuid)
ATS_SECRET_KEY=${ATS_SECRET_KEY:-$RANDOM_ATS_SECRET_KEY}
echo "ATS_SECRET_KEY=$ATS_SECRET_KEY"

kubectl create -n $MR3_NAMESPACE configmap client-am-config \
  --from-literal=key=$CLIENT_TO_AM_TOKEN_KEY \
  --from-literal=timestamp=$MR3_APPLICATION_ID_TIMESTAMP \
  --from-literal=mr3sessionid=$MR3_SHARED_SESSION_ID \
  --from-literal=ats-secret-key=$ATS_SECRET_KEY

kubectl create -f $YAML_DIR/metastore.yaml
kubectl create -f $YAML_DIR/metastore-service.yaml

