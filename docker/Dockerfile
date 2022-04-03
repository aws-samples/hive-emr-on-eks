FROM openjdk:8-slim

ARG HMS_VERSION=3.0.0
ARG HADOOP_VERSION=3.3.2
ARG MYSQL_CONNECTOR_VERSION=8.0.28
# ARG aws_java_sdk_version=1.12.37
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y curl unzip --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Gomplate
RUN curl -sfSL https://github.com/hairyhenderson/gomplate/releases/download/v3.6.0/gomplate_linux-amd64 \
      -o /usr/local/bin/gomplate \
    && chmod 755 /usr/local/bin/gomplate

# Set Hadoop/HiveMetastore variables and Classpath
ENV HADOOP_HOME="/opt/hadoop"
ENV METASTORE_HOME="/opt/hive-metastore"
ENV HADOOP_CLASSPATH="${HADOOP_HOME}/share/hadoop/tools/lib/*:${HADOOP_HOME}/share/hadoop/common/lib/*"
ENV PATH="${HADOOP_HOME}/bin:${METASTORE_HOME}/lib/mysql-connector-java.jar:${PATH}"

# Download Hadoop
RUN curl -s https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
        | tar xz -C /opt/  \
        && ln -s ${HADOOP_HOME}-$HADOOP_VERSION ${HADOOP_HOME} \
        && rm -r ${HADOOP_HOME}/share/doc

WORKDIR ${HADOOP_HOME}/share/hadoop
# Add additional jars to the Hadoop classpath to enable S3, IRSA in EKS
RUN curl -s -o tools/lib/log4j-1.2-api-2.17.2.jar https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-1.2-api/2.17.2/log4j-1.2-api-2.17.2.jar && \
    curl -s -o tools/lib/log4j-api-2.17.2.jar https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-api/2.17.2/log4j-api-2.17.2.jar && \
    curl -s -o tools/lib/log4j-core-2.17.2.jar https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/2.17.2/log4j-core-2.17.2.jar && \
    curl -s -o tools/lib/log4j-slf4j18-impl-2.17.2.jar https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-slf4j18-impl/2.17.2/log4j-slf4j18-impl-2.17.2.jar  && \
    # curl -s -o aws-java-sdk-bundle-${aws_java_sdk_version}.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${aws_java_sdk_version}/aws-java-sdk-bundle-${aws_java_sdk_version}.jar && \
    # curl -s -o aws-java-sdk-sts-${aws_java_sdk_version}.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-sts/${aws_java_sdk_version}/aws-java-sdk-sts-${aws_java_sdk_version}.jar && \
    # rm tools/lib/aws-java-sdk* && \
    # mv aws-java-sdk-*.jar tools/lib/ && \
    # ln -s tools/lib/hadoop-aws* common/lib/ && \
    # ln -s tools/lib/aws-java-sdk* common/lib/ && \
    curl -s -o tools/lib/mysql-connector-java.jar https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-${MYSQL_CONNECTOR_VERSION}.jar && \
    ln -s tools/lib/mysql-connector-java* common/lib/ && \
    chmod 0644 tools/lib/*

# Download the standalone hive metastore 
RUN curl -s https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${HMS_VERSION}/hive-standalone-metastore-${HMS_VERSION}-bin.tar.gz \
        | tar xz -C /opt/ \
        && ln -s /opt/apache-hive-metastore-${HMS_VERSION}-bin ${METASTORE_HOME}

# Add additional jars to the HMS classpath & mitigate log4j issues from CVE-2021-44228
WORKDIR ${METASTORE_HOME}
RUN rm lib/log4j-* && \
    # rm lib/guava-* && \
    ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/log4j-* lib/ && \
    # ln -s $HADOOP_HOME/share/hadoop/common/lib/guava-*.jar lib/ && \
    # ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/hadoop-aws* lib/ && \
    # ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/aws-java-sdk-sts* lib/ && \
    ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/mysql-connector-java* lib/ && \
    chmod 0644 lib/*

COPY conf/metastore-log4j2.properties conf
COPY entrypoint.sh bin/
RUN chmod +x bin/entrypoint.sh

EXPOSE 9083
ENTRYPOINT ["bin/entrypoint.sh"]