## Build HMS Docker image
The docker image is used by the [Hive Helm Chart](../hive-metastore-chart/README.md) and the hms sidecar [pod template](../deployment/app_code/job/sidecar_hms_pod_template.yaml).

This repo has the [auto-build workflow](../.github/workflows/HMS-docker.yml) in place. If permission is allowed, it can automatically build the [HMS docker image](Dockerfile) triggered by any code changes in the main branch. 

Alternatively, manually build the docker image with a flexibility of choosing the different HMS & Hadoop versions. See the sample command:
```bash
cd docker
export DOCKERHUB_USERNAME=<your_dockerhub_username>
docker build -t $DOCKERHUB_USERNAME/hive-metastore:3.0.0 --build-arg HADOOP_VERSION=3.3.2 --build-arg HMS_VERSION=3.0.0 .
docker push $DOCKERHUB_USERNAME/hive-metastore:3.0.0
```
## Update Docker image name
- [values.yaml](../hive-metastore-chart/values.yaml): update the helm chart value file if manually install the chart.
- [hive-metastore-values.yaml](../source/app_resources/hive-metastore-values.yaml): edit the solution's chart value file with your newly build docker image name and version, then regenerate the CFN template or use `cdk deploy` directly.
- [sidecar_hms_pod_template.yaml](../deployment/app_code/job/sidecar_hms_pod_template.yaml): update the docker image name and version if need to run the sidecar HMS.
