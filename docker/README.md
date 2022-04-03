## Build HMS Docker image
The docker image is used by the [Hive Helm Chart](../hive-metastore-chart/README.md) and the hms sidecar [pod template](../deployment/app_code/job/sidecar_hms_pod_template.yaml).

This repo has the [auto-build workflow](../.github/workflows/HMS-docker.yml) enabled, which automatically builds the [HMS docker image](https://github.com/aws-samples/hive-emr-on-eks/pkgs/container/hive-metastore) triggered by any code changes in the main branch. 

If you want to build manually with different build argument, see the sample command:
```bash
cd docker
export DOCKERHUB_USERNAME=<your_dockerhub_username>
docker build -t $DOCKERHUB_USERNAME/hive-metastore:3.0.0_hadoop_3.3.2 --build-arg HADOOP_VERSION=3.3.2 --build-arg HMS_VERSION=3.0.0 .
docker push $DOCKERHUB_USERNAME/hive-metastore:3.0.0_hadoop_3.3.2
```

- [values.yaml](../hive-metastore-chart/values.yaml): update the docker image name and version on the helm chart value file
- [Dockerfile](./Dockerfile): if needed, edit the the docker image definition file that includes Hadoop binary package, standalone hive-metastore and RDS mysql driver.
