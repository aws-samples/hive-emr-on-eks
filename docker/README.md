# Hive Metastore Service Docker Image

A multi-architecture Docker image for Apache Hive Metastore Service (HMS) that supports both local and S3-based
warehouse directories.

## Features

- Multi-architecture support (ARM64/AMD64)
- MySQL database connectivity
- S3 warehouse support with AWS credentials integration
- Schema validation and auto-initialization
- Self-termination capability for container lifecycle management
- Configurable through environment variables
- Support for additional Hive configuration parameters

## Build

The docker image is used by the Hive Helm Chart and the HMS sidecar pod template.

### Build Options

The Docker image can be built in two modes:

- **Standard Mode**: Without templates (default)
- **Sidecar Mode**: With templates included (recommended for sidecar usage)

### Manual Build Commands

```bash
cd docker
export DOCKERHUB_USERNAME=<your_dockerhub_username>

# Build without templates (standard mode)
docker build -t $DOCKERHUB_USERNAME/hive-metastore:3.0.0  .

# Build with templates (sidecar mode)
docker build -t $DOCKERHUB_USERNAME/hive-metastore:3.0.0-with-templates \
  --build-arg BUILD_ENV=templates .

# Push the image
docker push $DOCKERHUB_USERNAME/hive-metastore:3.0.0
```

### Build Arguments

| Argument                | Description                                | Default      |
|-------------------------|--------------------------------------------|--------------|
| HADOOP_VERSION          | Version of Hadoop to install               | 3.4.1        |
| HMS_VERSION             | Version of Hive Metastore to install       | 3.0.0        |
| BUILD_ENV               | Build environment (templates/no_templates) | no_templates |
| JAVA_IMAGE_TAG          | Base Java image tag                        | 17-jdk-noble |
| AWS_SDK_VERSION         | AWS SDK version                            | 2.29.17      |
| MYSQL_CONNECTOR_VERSION | MySQL Connector version                    | 9.1.0        |
| LOG4J_VERSIONS          | Log4j version                              | 2.24.1       |

## Environment Variables

### Required Variables

| Variable         | Description                                             | Required |
|------------------|---------------------------------------------------------|----------|
| HIVE_DB_HOST     | MySQL database host                                     | Yes      |
| HIVE_DB_PORT     | MySQL database port                                     | Yes      |
| HIVE_DB_NAME     | Database name                                           | Yes      |
| HIVE_DB_DRIVER   | JDBC driver class                                       | Yes      |
| HIVE_DB_USER     | Database username                                       | Yes      |
| HIVE_DB_PASS     | Database password                                       | Yes      |
| HIVE_DB_EXTERNAL | Set to "true" to enable external database configuration | Yes      |

### Storage Configuration

| Variable                  | Description                          | Default                                                            |
|---------------------------|--------------------------------------|--------------------------------------------------------------------|
| HIVE_WAREHOUSE_DIR        | S3 path for Hive warehouse directory | file:///tmp/                                                       |
| HIVE_WAREHOUSE_S3LOCATION | S3 bucket for default filesystem     | None                                                               |
| HIVE_CREDENTIALS_PROVIDER | AWS credentials provider class       | software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider |

### Schema Control

| Variable            | Description                                    | Default |
|---------------------|------------------------------------------------|---------|
| ENABLE_SCHEMA_CHECK | Enable schema validation                       | false   |
| AUTO_INIT_SCHEMA    | Automatically initialize schema if not present | false   |

### Self-Termination Control

| Variable                         | Description                                | Default                                    |
|----------------------------------|--------------------------------------------|--------------------------------------------|
| ENABLE_SELF_TERMINATE            | Enable self-terminate functionality        | false                                      |
| SELF_TERMINATE_FILE              | File to monitor for heartbeats             | /var/log/fluentd/main-container-terminated |
| SELF_TERMINATE_INTERVAL          | Check interval in seconds                  | 5                                          |
| SELF_TERMINATE_INIT_TIMEOUT      | Maximum time to wait for file in seconds   | 60                                         |
| SELF_TERMINATE_HEARTBEAT_TIMEOUT | Maximum time between heartbeats in seconds | 10                                         |

### Additional Configuration

| Variable         | Description                                                               | Default |
|------------------|---------------------------------------------------------------------------|---------|
| HIVE_CONF_PARAMS | Additional configuration parameters (semicolon-separated key:value pairs) | None    |

## Usage Examples

### Basic Usage with Local Storage

```bash
docker run \
  -p 9083:9083 \
  -e HIVE_DB_EXTERNAL=true \
  -e HIVE_DB_HOST=mysql-host \
  -e HIVE_DB_PORT=3306 \
  -e HIVE_DB_NAME=hive_metastore \
  -e HIVE_DB_DRIVER=com.mysql.cj.jdbc.Driver \
  -e HIVE_DB_USER=hive \
  -e HIVE_DB_PASS=password \
  your-registry/hive-metastore:latest
```

### Usage with S3 Storage and Schema Control

```bash
docker run \
  -p 9083:9083 \
  -e HIVE_DB_EXTERNAL=true \
  -e HIVE_DB_HOST=mysql-host \
  -e HIVE_DB_PORT=3306 \
  -e HIVE_DB_NAME=hive_metastore \
  -e HIVE_DB_DRIVER=com.mysql.cj.jdbc.Driver \
  -e HIVE_DB_USER=hive \
  -e HIVE_DB_PASS=password \
  -e HIVE_WAREHOUSE_DIR=s3://my-bucket/warehouse \
  -e HIVE_WAREHOUSE_S3LOCATION=my-bucket \
  -e AWS_ACCESS_KEY_ID=your-access-key \
  -e AWS_SECRET_ACCESS_KEY=your-secret-key \
  -e ENABLE_SCHEMA_CHECK=true \
  -e AUTO_INIT_SCHEMA=true \
  your-registry/hive-metastore:latest
```

### With Self-Termination and Custom Configuration

```bash
docker run \
  -p 9083:9083 \
  -e HIVE_DB_EXTERNAL=true \
  -e HIVE_DB_HOST=mysql-host \
  -e ENABLE_SELF_TERMINATE=true \
  -e SELF_TERMINATE_HEARTBEAT_TIMEOUT=30 \
  -e HIVE_CONF_PARAMS="hive.metastore.event.db.notification.api.auth:false;hive.metastore.metrics.enabled:true" \
  your-registry/hive-metastore:latest
```

## Configuration Files

The image includes several configuration templates:

- `core-site.xml`: Configures Hadoop core settings and S3 integration
- `metastore-site.xml`: Configures Hive Metastore service settings and database connectivity
- `pom.xml`: Manages AWS SDK dependencies

## Port

The Hive Metastore Service runs on port 9083 by default.

## Update Docker Image References

After building a new image, update the following files with the new image name and version:

- `values.yaml`: Update the helm chart value file if manually installing the chart
- `hive-metastore-values.yaml`: Edit the solution's chart value file
- `sidecar_hms_pod_template.yaml`: Update the docker image name and version (use templates image for sidecar)
