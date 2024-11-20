ARG JAVA_IMAGE_TAG=17-jdk-noble
ARG BUILD_ENV=no_templates

# Template stages with ONBUILD triggers
FROM eclipse-temurin:${JAVA_IMAGE_TAG} AS build_templates
ENV METASTORE_HOME="/opt/hive-metastore"
ONBUILD COPY templates "/build/templates/"
ONBUILD COPY self-terminate.sh "/build/scripts/self-terminate.sh"

FROM eclipse-temurin:${JAVA_IMAGE_TAG} AS build_no_templates
ENV METASTORE_HOME="/opt/hive-metastore"
ONBUILD RUN echo "Skipping templates copy"

# Continue from the selected template stage
FROM build_${BUILD_ENV}

ARG HMS_VERSION=3.0.0
ARG HADOOP_VERSION=3.4.1
ARG MYSQL_CONNECTOR_VERSION=9.1.0
ARG LOG4J_VERIONS=2.24.1
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt update && apt install -y curl wget unzip procps --no-install-recommends && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*



# Install Gomplate with architecture detection
RUN ARCH=$(uname -m); \
    case ${ARCH} in \
        x86_64) GOMPLATE_ARCH="linux-amd64" ;; \
        aarch64) GOMPLATE_ARCH="linux-arm64" ;; \
        arm64) GOMPLATE_ARCH="linux-arm64" ;; \
        *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
    esac && \
    curl -sfSL "https://github.com/hairyhenderson/gomplate/releases/download/v3.6.0/gomplate_${GOMPLATE_ARCH}" \
        -o /usr/local/bin/gomplate && \
    chmod 755 /usr/local/bin/gomplate



# Set Hadoop/HiveMetastore Classpath
ENV HADOOP_HOME="/opt/hadoop"
ENV METASTORE_HOME="/opt/hive-metastore"
ENV HADOOP_CLASSPATH="${HADOOP_HOME}/share/hadoop/tools/lib/*:${HADOOP_HOME}/share/hadoop/common/lib/*"
ENV PATH="${HADOOP_HOME}/bin:${METASTORE_HOME}/lib/mysql-connector-java.jar:${PATH}"



# Download and install Hadoop
RUN wget https://downloads.apache.org/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}-lean.tar.gz && \
    tar -xzf hadoop-${HADOOP_VERSION}-lean.tar.gz && \
    rm hadoop-${HADOOP_VERSION}-lean.tar.gz && \
    mv hadoop-${HADOOP_VERSION} $HADOOP_HOME && \
    rm -r ${HADOOP_HOME}/share/doc



# Add additional jars to the Hadoop classpath
ARG LIB_DIR=${HADOOP_HOME}/share/hadoop/tools/lib

ADD https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-1.2-api/${LOG4J_VERIONS}/log4j-1.2-api-${LOG4J_VERIONS}.jar $LIB_DIR/
ADD https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-api/${LOG4J_VERIONS}/log4j-api-${LOG4J_VERIONS}.jar $LIB_DIR/
ADD https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/${LOG4J_VERIONS}/log4j-core-${LOG4J_VERIONS}.jar $LIB_DIR/
ADD https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-slf4j18-impl/2.18.0/log4j-slf4j18-impl-2.18.0.jar $LIB_DIR/
ADD https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar $LIB_DIR/mysql-connector-java.jar


RUN ln -s $LIB_DIR/mysql-connector-java* ${HADOOP_HOME}/share/hadoop/common/lib/ && \
    chmod 0644 ${LIB_DIR}/*


# Download the standalone hive metastore
RUN wget https://downloads.apache.org/hive/hive-standalone-metastore-${HMS_VERSION}/hive-standalone-metastore-${HMS_VERSION}-bin.tar.gz && \
    tar -xzf hive-standalone-metastore-${HMS_VERSION}-bin.tar.gz && \
    rm hive-standalone-metastore-${HMS_VERSION}-bin.tar.gz && \
    mv apache-hive-metastore-${HMS_VERSION}-bin $METASTORE_HOME



# Add additional jars to the HMS classpath & mitigate log4j issues from CVE-2021-44228
WORKDIR ${METASTORE_HOME}
RUN rm lib/log4j-* && \
   ln -s ${LIB_DIR}/log4j-* lib/ && \
   ln -s ${LIB_DIR}/mysql-connector-java* lib/ && \
   chmod 0644 lib/*

RUN if [ -d "/build/templates" ]; then \
        mkdir -p "${METASTORE_HOME}/conf/templates/" && \
        cp -r /build/templates/* "${METASTORE_HOME}/conf/templates/" && \
        cp /build/scripts/self-terminate.sh /bin/self-terminate.sh ; \
    else \
        echo "Templates directory not found, skipping copy"; \
    fi

COPY conf/metastore-log4j2.properties conf/
COPY entrypoint.sh bin/
RUN chmod +x bin/entrypoint.sh

EXPOSE 9083
ENTRYPOINT ["bin/entrypoint.sh"]