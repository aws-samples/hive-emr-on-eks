# HMS (Hive Metastore Service) Helm Chart 

Beginning in Hive 3.0, Hive Metastore can be run without the rest of Hive being installed. This decoupling provides us a way to implement the Metastore service as a stateless microservice in Kubernetes infrastructure. This Helm chart (package) encapsulates all configurations and components needed to deploy a HNS, and helps us to easily install a HMS as a scalable and secure k8s application. 

Get the Helm command tool:
```bash
sudo yum install openssl && curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

helm version --short
```
## How to use it
### Install with Helm
Replace placeholders in the [values file](values.yaml) as below. Alternatively, secure your Hive metastore credentials in AWS Secrets manager via this [CDK value file](https://github.com/aws-samples/hive-emr-on-eks/blob/main/source/app_resources/hive-metastore-values.yaml). 
```bash
echo -e "\n Default HDFS: $S3BUCKET\n Service Account IAM role: $EMR_ROLE_ARN\n host: $HOST_NAME\n DB: $DB_NAME\n password: $PASSWORD\n username: $USER_NAME\n"

cd hive-metastore-chart

sed -i '' -e 's/{RDS_JDBC_URL}/"jdbc:mysql:\/\/'$HOST_NAME':3306\/'$DB_NAME'?createDatabaseIfNotExist=true"/g' values.yaml 
sed -i '' -e 's/{RDS_USERNAME}/'$USER_NAME'/g' values.yaml 
sed -i '' -e 's/{RDS_PASSWORD}/'$PASSWORD'/g' values.yaml
sed -i '' -e 's/{S3BUCKET}/s3:\/\/'$S3BUCKET'/g' values.yaml
sed -i '' -e 's/{}/{"eks.amazonaws.com/role-arn":'$EMR_ROLE_ARN'}/g' values.yaml
```

```bash
helm repo add hive-metastore https://melodyyangaws.github.io/hive-metastore-chart
helm install hive hive-metastore/hive-metastore -f values.yaml --namespace=emr --debug
```
### Security consideration
Leveraging the k8s's [External Secrets Operator(ESO)](https://external-secrets.io/v0.4.4/guides-getting-started/) or the [k8s External Secrets](https://github.com/external-secrets/kubernetes-external-secrets) tool, we can automate the password retrieval process in order to connect to the Hive metastore database. 

Check out the [example values.yaml file](../source/app_resources/hive-metastore-values.yaml#L23) deployed by the solution's CFN/CDK templates, and a sidecar [pod template example](../deployment/app_code/job/sidecar_hms_pod_template.yaml#L48).


## EKS resources used in this Helm chart
The resources used in the this chart are defined in yaml files inside [`/templates` directory](./templates). The following resources are used:

- [Configmap](templates/configmap.yaml): creates volumes that can be attached to containers. Here, we're mounting a volume to the [HMS configsets directory](hive-metastore-chart/configsets), which will be used by the HMS docker image to render the [metastore-site.yaml](configsets/metastore-site.xml.tpl) and hadoop's [core-site.yaml](configsets/core-site.xml.tpl) templates.
- [Service](templates/service.yaml): exposes the HMS service as a ClusterIP type of service.
- [Horizontal Pods Autoscaler (HPA)](templates/hpa.yaml):  To guarantee the HMS service availability, the HPA automatically increases or decreases the number of pods available in a ReplicaSet based on certain thresholds (memory and cpu).
- [Deployment](templates/deployment.yaml): the main resource, because it specifies pod's configurations and is the link between all resources and the HMS pods.
