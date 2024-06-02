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

FROM openjdk:8-jdk-slim
MAINTAINER Sungwoo Park "glapark@gmail.com"

USER root

# create directories under /opt/mr3-run/ranger

RUN mkdir -p /opt/mr3-run/ranger && \
    mkdir -p /opt/mr3-run/ranger/key && \
    mkdir -p /opt/mr3-run/ranger/conf && \
    mkdir -p /opt/mr3-run/ranger/work-dir && \
    mkdir -p /opt/mr3-run/ranger/work-local-dir

# copy files

COPY start-solr.sh /opt/mr3-run/ranger/
COPY start-ranger.sh /opt/mr3-run/ranger/
COPY solr /opt/mr3-run/ranger/solr
COPY ranger-admin /opt/mr3-run/ranger/ranger-admin
COPY lib /opt/mr3-run/lib

# set environments

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y python2.7 bc procps wget

WORKDIR /opt/mr3-run/ranger

ARG USER=ranger
ARG GROUP=$USER
ARG UID=1000
ARG GID=1000
RUN groupadd -g $GID $GROUP && \
    useradd --no-log-init -u $UID -g $GID $USER && \
    chown -R $USER:$GROUP /opt/mr3-run/ranger

# run as root because ranger sets up init.d

