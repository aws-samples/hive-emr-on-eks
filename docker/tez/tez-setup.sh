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
# for running jobs
#

function tez_setup_init {
    TEZ_LIB_DIR=$TEZ_BASE_DIR/tezjar
    TEZ_CLASSPATH=$TEZ_LIB_DIR/*:$TEZ_LIB_DIR/lib/*
}

