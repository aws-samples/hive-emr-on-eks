ARG JAVA_IMAGE_TAG=17-jdk-noble
ARG BUILD_ENV=templates

# Template stages with ONBUILD triggers
FROM eclipse-temurin:${JAVA_IMAGE_TAG} AS build_templates
ENV METASTORE_HOME="/opt/hive-metastore"
ONBUILD COPY templates "/build/templates/"

FROM eclipse-temurin:${JAVA_IMAGE_TAG} AS build_no_templates
ENV METASTORE_HOME="/opt/hive-metastore"
ONBUILD RUN echo "Skipping templates copy"

FROM maven:3-eclipse-temurin-17-focal AS java-builder
ARG HADOOP_VERSION=3.3.0
ARG AWS_SDK_V1_VERSION="1.12.778"
ARG AWS_SDK_V2_VERSION="2.29.17"

# Create a temporary pom.xml
WORKDIR /build
COPY templates/pom-sdk-* ./templates/

## Add version comparison function
RUN printf '%s\n' 'verlte() {' \
    '  printf "%s\n" "$1" "$2" | sort -C -V' \
    '}' > /usr/local/bin/verlte && \
    chmod +x /usr/local/bin/verlte


# Set AWS SDK version and select template and replace placeholder with actual version and create pom.xml
RUN . /usr/local/bin/verlte && \
    if verlte "3.4.0" "$HADOOP_VERSION"; then \
      sed "s/\${AWS_SDK_VERSION}/$AWS_SDK_V2_VERSION/g" templates/pom-sdk-v2.xml.tpl > pom.xml; \
    else \
      sed "s/\${AWS_SDK_VERSION}/$AWS_SDK_V1_VERSION/g" templates/pom-sdk-v1.xml.tpl > pom.xml; \
    fi


# Download dependencies and show the directory contents
RUN mvn dependency:copy-dependencies -DoutputDirectory=/build/dependencies


# Continue from the selected template stage
FROM build_${BUILD_ENV}

ARG HMS_VERSION=3.0.0
ARG HADOOP_VERSION=3.3.0
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


# Copy verlte function from java-builder stage
COPY --from=java-builder /usr/local/bin/verlte /usr/local/bin/verlte

# Then modify the Hadoop download part to use verlte
RUN . /usr/local/bin/verlte && \
    if verlte "3.4.1" "${HADOOP_VERSION}"; then \
        wget https://downloads.apache.org/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}-lean.tar.gz; \
    else \
        wget https://downloads.apache.org/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz; \
    fi

# Remove unnecesarry lib
RUN tar -xzf hadoop-${HADOOP_VERSION}*.tar.gz && \
    rm hadoop-${HADOOP_VERSION}*.tar.gz && \
    mv hadoop-${HADOOP_VERSION} $HADOOP_HOME && \
    rm -r ${HADOOP_HOME}/share/doc && \
    rm -r ${HADOOP_HOME}/share/hadoop/mapreduce/* && \
    rm -r ${HADOOP_HOME}/share/hadoop/yarn/* && \
    rm -r ${HADOOP_HOME}/share/hadoop/hdfs/* && \
    rm -r ${HADOOP_HOME}/share/hadoop/client/* && \
    rm -r ${HADOOP_HOME}/lib/native && \
    rm -f ${HADOOP_HOME}/share/hadoop/tools/lib/aws-java-sdk-bundle-1.* && \
    rm -f ${HADOOP_HOME}/share/hadoop/tools/lib/bundle-2.*



# Download and install Hive Metastore Standalone (HMS)
RUN wget https://downloads.apache.org/hive/hive-standalone-metastore-${HMS_VERSION}/hive-standalone-metastore-${HMS_VERSION}-bin.tar.gz && \
    tar -xzf hive-standalone-metastore-${HMS_VERSION}-bin.tar.gz && \
    rm hive-standalone-metastore-${HMS_VERSION}-bin.tar.gz && \
    mv apache-hive-metastore-${HMS_VERSION}-bin $METASTORE_HOME


# Add additional jars to the Hadoop classpath
ARG LIB_DIR=${HADOOP_HOME}/share/hadoop/tools/lib

# Add AWS Log4j and MySQL Driver dependencies
RUN wget -P $LIB_DIR https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-1.2-api/${LOG4J_VERIONS}/log4j-1.2-api-${LOG4J_VERIONS}.jar && \
    wget -P $LIB_DIR https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-api/${LOG4J_VERIONS}/log4j-api-${LOG4J_VERIONS}.jar && \
    wget -P $LIB_DIR https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/${LOG4J_VERIONS}/log4j-core-${LOG4J_VERIONS}.jar && \
    wget -P $LIB_DIR https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-slf4j18-impl/2.18.0/log4j-slf4j18-impl-2.18.0.jar && \
    wget -P $LIB_DIR https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar -O $LIB_DIR/mysql-connector-java.jar


# Add AWS SDK dependencies
COPY --from=java-builder /build/dependencies $LIB_DIR

RUN ln -s $LIB_DIR/mysql-connector-java* ${HADOOP_HOME}/share/hadoop/common/lib/ && \
    chmod 0644 ${LIB_DIR}/*


# Add additional jars, templates to the HMS classpath & mitigate log4j issues from CVE-2021-44228
WORKDIR ${METASTORE_HOME}
RUN rm lib/log4j-* && \
    ln -s ${LIB_DIR}/log4j-* lib/ && \
    ln -s ${LIB_DIR}/mysql-connector-java* lib/ && \
    chmod 0644 lib/* && \
    if [ -d "/build/templates" ]; then \
        mkdir -p "${METASTORE_HOME}/conf/templates/" && \
        cp -r /build/templates/* "${METASTORE_HOME}/conf/templates/"; \
    else \
        echo "Templates directory not found, skipping copy"; \
    fi

COPY conf/metastore-log4j2.properties conf/
COPY entrypoint.sh bin/
COPY self-terminate.sh bin/
RUN chmod +x bin/entrypoint.sh

EXPOSE 9083
ENTRYPOINT ["bin/entrypoint.sh"]