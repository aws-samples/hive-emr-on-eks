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

run_kubernetes_parse_args $@

if [ $ENABLE_SSL_RANGER = true ]; then
  create_hivemr3_ssl_certificate $BASE_DIR/ranger-key
fi

if [[ $GENERATE_TRUSTSTORE_ONLY = true ]]; then
  exit 0
fi

# run as the user who has set up ~/.kube/config

# Namespace
kubectl create namespace $MR3_NAMESPACE

# Volumes
if [ $RUN_AWS_EKS = true ]; then
  echo "assume that PersistentVolumeClaim workdir-pvc has been created"
else
  kubectl create -f $YAML_DIR/workdir-pv-ranger.yaml
  kubectl create -n $MR3_NAMESPACE -f $YAML_DIR/workdir-pvc-ranger.yaml
fi

# ConfigMaps
kubectl create -n $MR3_NAMESPACE configmap hivemr3-ranger-conf-configmap --from-file=$BASE_DIR/ranger-conf/

# Secrets
if [ $CREATE_RANGER_SECRET = true ]; then
  kubectl create -n $MR3_NAMESPACE secret generic hivemr3-ranger-secret --from-file=$BASE_DIR/ranger-key/
else 
  kubectl create -n $MR3_NAMESPACE secret generic hivemr3-ranger-secret
fi

# App
kubectl create -f $YAML_DIR/ranger.yaml
kubectl create -f $YAML_DIR/ranger-service.yaml
