# HMS (Hive Metastore Service) Helm Chart 

Beginning in Hive 3.0, Hive Metastore can be run without the rest of Hive being installed.This decoupling provides us a way to implement the Metastore service as a stateless microservice in Kubernetes infrastructure. This Helm chart (package) encapsulates all configurations and components needed to deploy a HNS, and helps us to easily install a NHS as a scalable and secure k8s application. 

## Install the Chart
Install the Helm CLI tool:
```bash
sudo yum install openssl && curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

helm version --short
```

Replace placeholders in the [values file](values.yaml) as below. Alternatively, secure your Hive metastore credentials in AWS Secrets manager via this [CDK value file](https://github.com/aws-samples/hive-emr-on-eks/blob/main/source/app_resources/hive-metastore-values.yaml). 
```bash
echo -e "\n Default HDFS: $S3BUCKET\n host: $HOST_NAME\n DB: $DB_NAME\n passowrd: $PASSWORD\n username: $USER_NAME\n"

cd hive-metastore-chart

sed -i '' -e 's/{RDS_JDBC_URL}/"jdbc:mysql:\/\/'$HOST_NAME':3306\/'$DB_NAME'?createDatabaseIfNotExist=true"/g' values.yaml 
sed -i '' -e 's/{RDS_USERNAME}/'$USER_NAME'/g' values.yaml 
sed -i '' -e 's/{RDS_PASSWORD}/'$PASSWORD'/g' values.yaml
sed -i '' -e 's/{S3BUCKET}/s3:\/\/'$S3BUCKET'/g' values.yaml
```

```bash
# install Helm chart
helm repo add hive-metastore https://aws-samples.github.io/hive-metastore-chart 
helm install hive hive-metastore/hive-metastore -f values.yaml --namespace=emr --debug
```

## EKS Resources used in this Hive Chart

The resources used in the this chart are defined in yaml files inside [`/templates` directory](./templates). The following resources are used:

- [Configmap](templates/configmap.yaml): this k8a resource creates volumes that can be attached to containers. Here, we're mounting a volume to the [HMS configuration templates directory](templates/deployment.yaml#L65), which will be used by the HMS docker image to render the `metastore-site.yaml` config file.
- [Service](templates/service.yaml): this resources is responsible to expose the HMS service to the external.
- Horizontal Pods Autoscaler ([HPA](templates/hpa.yaml)): this resource increases the number of pods available in a ReplicaSet based on some thresholds (memory and cpu) in order to guarantee the service availability
- [Deployment](templates/deployment.yaml): the main resource, because it specifies pod's configurations and is the link between all resources and the HMS pods.
