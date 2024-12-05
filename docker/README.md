## Build HMS Docker image
The docker image is used by the [Hive Helm Chart](../hive-metastore-chart/README.md) and the hms sidecar [pod template](../deployment/app_code/job/sidecar_hms_pod_template.yaml).

This repo has the [auto-build workflow](../.github/workflows/HMS-docker.yml) in place. If permission is allowed, it can automatically build the [HMS docker image](Dockerfile) triggered by any code changes in the main branch. 

### Build Options

The Docker image can be built in two modes:
- **Standard Mode**: Without templates (default)
- **Sidecar Mode**: With templates included (recommended for sidecar usage)

#### Manual Build Commands
```bash
cd docker
export DOCKERHUB_USERNAME=<your_dockerhub_username>

# Build without templates (standard mode)
docker build -t $DOCKERHUB_USERNAME/hive-metastore:3.0.0 \
  --build-arg HADOOP_VERSION=3.3.2 \
  --build-arg HMS_VERSION=3.0.0 \
  --build-arg BUILD_ENV=no_templates .

# Build with templates (sidecar mode)
docker build -t $DOCKERHUB_USERNAME/hive-metastore:3.0.0-with-templates \
  --build-arg HADOOP_VERSION=3.3.2 \
  --build-arg HMS_VERSION=3.0.0 \
  --build-arg BUILD_ENV=templates .

# Push the image
docker push $DOCKERHUB_USERNAME/hive-metastore:3.0.0
```

### Build Arguments
- `HADOOP_VERSION`: Version of Hadoop to install (default: 3.4.1)
- `HMS_VERSION`: Version of Hive Metastore to install (default: 3.0.0)
- `BUILD_ENV`: Build environment, either `templates` or `no_templates` (default: no_templates)
- `JAVA_IMAGE_TAG`: Base Java image tag (default: 17-jdk-noble)

### Environment Variables
When running the container in sidecar mode, the following environment variables are used to configure the Hive Metastore:

#### Logging Configuration
- `VERBOSE`: Enable verbose logging when set to "true" (default: false)
  - When enabled, adds the `--verbose` flag to the metastore startup command
  - Provides more detailed logging output for troubleshooting

#### S3 Configuration (core-site.xml)
- `HIVE_WAREHOUSE_S3LOCATION`: S3 bucket location for the warehouse (optional)
  - When set, configures the default filesystem to use S3

#### Database Configuration (metastore-site.xml)
Required when `HIVE_DB_EXTERNAL=true`:
- `HIVE_DB_EXTERNAL`: Set to "true" to enable external database configuration
- `HIVE_DB_HOST`: Database host
- `HIVE_DB_PORT`: Database port
- `HIVE_DB_NAME`: Database name
- `HIVE_DB_DRIVER`: JDBC driver class (e.g., "com.mysql.cj.jdbc.Driver")
- `HIVE_DB_USER`: Database username
- `HIVE_DB_PASS`: Database password

#### Warehouse Configuration
- `HIVE_WAREHOUSE_DIR`: Warehouse directory location
  - If not set, defaults to "file:///tmp/"
  - If set, will be automatically prefixed with "s3:" for S3 locations

#### Additional Configuration
- `HIVE_CONF_PARAMS`: Semicolon-separated list of additional configuration parameters
  - Format: "property1:value1;property2:value2"
  - Example: "hive.metastore.event.db.notification.api.auth:false;hive.metastore.strict.managed.tables:true"

Example environment configuration for sidecar mode:
```bash
# Logging Configuration
export VERBOSE=true

# Basic Configuration
export HIVE_WAREHOUSE_S3LOCATION=my-bucket/warehouse
export HIVE_WAREHOUSE_DIR=/my-bucket/warehouse

# Database Configuration
export HIVE_DB_EXTERNAL=true
export HIVE_DB_HOST=mysql.example.com
export HIVE_DB_PORT=3306
export HIVE_DB_NAME=metastore
export HIVE_DB_DRIVER=com.mysql.cj.jdbc.Driver
export HIVE_DB_USER=hive
export HIVE_DB_PASS=password

# Additional Parameters
export HIVE_CONF_PARAMS="hive.metastore.event.db.notification.api.auth:false;hive.metastore.strict.managed.tables:true"
```

## Update Docker Image References
After building a new image, update the following files with the new image name and version:

- [values.yaml](../hive-metastore-chart/values.yaml): Update the helm chart value file if manually installing the chart.
- [hive-metastore-values.yaml](../source/app_resources/hive-metastore-values.yaml): Edit the solution's chart value file with your newly built docker image name and version, then regenerate the CFN template or use `cdk deploy` directly.
- [sidecar_hms_pod_template.yaml](../deployment/app_code/job/sidecar_hms_pod_template.yaml): Update the docker image name and version. When using as a sidecar, it's recommended to use the image built with templates (`BUILD_ENV=templates`).