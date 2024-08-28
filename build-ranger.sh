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
RANGER_DIR=$BASE_DIR/ranger

source $BASE_DIR/env.sh

pushd $RANGER_DIR > /dev/null
sudo docker build -t $DOCKER_RANGER_IMG -f $DOCKER_RANGER_FILE .
sudo docker push $DOCKER_RANGER_IMG

