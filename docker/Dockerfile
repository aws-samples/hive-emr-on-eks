ARG JAVA_IMAGE_TAG=17-jdk-noble
ARG BUILD_ENV=templates
ARG HIVE_VERSION=3.1.3
ARG HADOOP_VERSION=3.4.1
ARG MYSQL_CONNECTOR_VERSION=9.1.0
ARG LOG4J_VERIONS=2.24.1
ARG AWS_SDK_V1_VERSION="1.12.778"
ARG AWS_SDK_V2_VERSION="2.29.17"


# Template stages with ONBUILD triggers
FROM eclipse-temurin:${JAVA_IMAGE_TAG} AS build_templates
ONBUILD COPY templates/core-site.xml.tpl "/build/templates/"
ONBUILD COPY templates/metastore-site.xml.tpl "/build/templates/"

FROM eclipse-temurin:${JAVA_IMAGE_TAG} AS build_no_templates
ONBUILD RUN echo "Skipping templates copy"


FROM maven:3-eclipse-temurin-17-focal AS java-builder
ARG HADOOP_VERSION
ARG AWS_SDK_V1_VERSION
ARG AWS_SDK_V2_VERSION

# Create a temporary pom.xml
WORKDIR /build
COPY templates/pom-sdk-* ./templates/

RUN printf '%s\n' 'verlte() {' \
    '  printf "%s\n" "$1" "$2" | sort -C -V' \
    '}' > /usr/local/bin/verlte && \
    chmod +x /usr/local/bin/verlte

# Set AWS SDK version and select template and replace placeholder with actual version and create pom.xml
RUN . /usr/local/bin/verlte && \
    if verlte "3.4.0" "$HADOOP_VERSION"; then \
      sed "s/\${AWS_SDK_VERSION}/$AWS_SDK_V2_VERSION/g" templates/pom-sdk-v2.xml.tpl > pom.xml && \
      echo "2" >> aws_sdk_version; \
    else \
      sed "s/\${AWS_SDK_VERSION}/$AWS_SDK_V1_VERSION/g" templates/pom-sdk-v1.xml.tpl > pom.xml && \
      echo "1" >> aws_sdk_version; \
    fi


# Download dependencies and show the directory contents
RUN mvn dependency:copy-dependencies -DoutputDirectory=/build/dependencies


FROM maven:3-eclipse-temurin-8-focal AS hms-builder
ARG HIVE_VERSION

WORKDIR /hive

RUN if [ -n "${HIVE_VERSION%%3*}" ]; then \
        echo "Building Hive ${HIVE_VERSION} from source" && \
        wget https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-src.tar.gz && \
        tar -xzf apache-hive-${HIVE_VERSION}-src.tar.gz && \
        rm apache-hive-${HIVE_VERSION}-src.tar.gz && \
        cd apache-hive-${HIVE_VERSION}-src/standalone-metastore && \
        # Apply patch specifically for Hive 4.0.0 (HIVE-28487)
        if [ "${HIVE_VERSION}" = "4.0.0" ]; then \
            sed -i 's/CLASS=org.apache.hadoop.hive.metastore.tools.MetastoreSchemaTool/CLASS=org.apache.hadoop.hive.metastore.tools.schematool.MetastoreSchemaTool/' \
                metastore-server/src/main/scripts/ext/schemaTool.sh; \
        fi && \
        mvn clean install -DskipTests -Pdist && \
        mv metastore-server/target/apache-hive-standalone-metastore-server-${HIVE_VERSION}-bin.tar.gz \
            /hive/hive-standalone-metastore-${HIVE_VERSION}-bin.tar.gz; \
    else \
        echo "Downloading Hive ${HIVE_VERSION} pre-built package" && \
        wget https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${HIVE_VERSION}/hive-standalone-metastore-${HIVE_VERSION}-bin.tar.gz ; \
    fi


# Continue from the selected template stage
FROM build_${BUILD_ENV} AS build

ARG HIVE_VERSION
ARG HADOOP_VERSION
ARG MYSQL_CONNECTOR_VERSION
ARG LOG4J_VERIONS

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


# Then modify the Hadoop download part to use verlte
RUN wget https://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz;

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
COPY --from=hms-builder /hive/hive-standalone-metastore-${HIVE_VERSION}-bin.tar.gz .
RUN tar -xzf hive-standalone-metastore-${HIVE_VERSION}-bin.tar.gz && \
    rm hive-standalone-metastore-${HIVE_VERSION}-bin.tar.gz && \
    mv apache-hive-metastore-${HIVE_VERSION}-bin $METASTORE_HOME


# Add additional jars to the Hadoop classpath
ARG LIB_DIR=${HADOOP_HOME}/share/hadoop/tools/lib

# Add AWS Log4j and MySQL Driver dependencies
RUN wget -P $LIB_DIR https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-1.2-api/${LOG4J_VERIONS}/log4j-1.2-api-${LOG4J_VERIONS}.jar && \
    wget -P $LIB_DIR https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-api/${LOG4J_VERIONS}/log4j-api-${LOG4J_VERIONS}.jar && \
    wget -P $LIB_DIR https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/${LOG4J_VERIONS}/log4j-core-${LOG4J_VERIONS}.jar && \
    wget -P $LIB_DIR https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-slf4j18-impl/2.18.0/log4j-slf4j18-impl-2.18.0.jar && \
    wget -P $LIB_DIR https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar -O $LIB_DIR/mysql-connector-java.jar && \
    wget -P $LIB_DIR https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-hdfs/${HADOOP_VERSION}/hadoop-hdfs-${HADOOP_VERSION}.jar -O $LIB_DIR/hadoop-hdfs-${HADOOP_VERSION}.jar


RUN ln -s $LIB_DIR/mysql-connector-java* ${HADOOP_HOME}/share/hadoop/common/lib/ && \
    chmod 0644 ${LIB_DIR}/*


# Add additional jars, templates to the HMS classpath & mitigate log4j issues from CVE-2021-44228
WORKDIR ${METASTORE_HOME}
RUN rm lib/log4j-* && rm lib/guava* && \
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


FROM eclipse-temurin:${JAVA_IMAGE_TAG}

# Set Hadoop/HiveMetastore Classpath
ENV HADOOP_HOME="/opt/hadoop"
ENV METASTORE_HOME="/opt/hive-metastore"
ENV HADOOP_CLASSPATH="${HADOOP_HOME}/share/hadoop/tools/lib/*:${HADOOP_HOME}/share/hadoop/common/lib/*"
ENV PATH="${HADOOP_HOME}/bin:${METASTORE_HOME}/lib/mysql-connector-java.jar:${PATH}"


# Add additional jars to the Hadoop classpath
ARG LIB_DIR=${HADOOP_HOME}/share/hadoop/tools/lib
COPY --from=java-builder /build/aws_sdk_version ${METASTORE_HOME}/conf/aws_sdk_version
COPY --from=java-builder /build/dependencies $LIB_DIR

# Add Go Template
COPY --from=build /usr/local/bin/gomplate /usr/local/bin/gomplate

# Add Hadoop
COPY --from=build /opt/hadoop /opt/hadoop

# Add Hive Metastore Standalone
COPY --from=build /opt/hive-metastore /opt/hive-metastore

WORKDIR ${METASTORE_HOME}
EXPOSE 9083
ENTRYPOINT ["bin/entrypoint.sh"]