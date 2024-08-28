# Run Hive metastore and Hive Server2 in EKS

This is a project containing multiple helm chart for Hive releated components.
Make sure you are in the correct branch

```bash
git clone -b hs2-hms git@github.com:aws-samples/hive-emr-on-eks.git
cd hive-emr-on-eks.git
```

We will reuse the configuration files in conf/ (and keys in key if Kerberos is used for authentication). 
Create symbolic links:
```bash
mkdir -p key
ln -s $(pwd)/conf/ helm/hive/conf
ln -s $(pwd)/key/ helm/hive/key
# ln -s $(pwd)/ranger-key/ helm/ranger/key
# ln -s $(pwd)/ranger-conf/ helm/ranger/conf
```
## Install the hive helm chart

```bash
# helm install ranger helm/ranger -f helm/values-ranger.yaml -n hive --create-namespace --debug
helm install hive helm/hive -f helm/values-hive.yaml -n hive --debug
```

## Uninstall the helm chart (OPTIONAL)

```bash
# helm uninstall ranger -n hive
helm uninstall hive -n hive
```

Before reinstall the chart, make sure that no ConfigMaps(cm), PVC, Services(svc) exist in the hive namespace. For example, query the left-over EKS objects like this:

```bash
kubectl get svc,pvc -n hive
```
```
NAME                  TYPE           CLUSTER-IP       EXTERNAL-IP                                                                         PORT(S)                          AGE
service/hiveserver2   LoadBalancer   10.100.151.165   k8s-hive-hiveserv-48ba99d5de-84e08bbf245f1ad5.elb.us-west-2.amazonaws.com,1.1.1.1   9852:31398/TCP,10001:32361/TCP   17m

NAME                                STATUS        VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/workdir-pvc   Terminating   workdir-pv   10Gi       RWX                           17m
```

Cleanup all:
```bash
kubectl delete svc,cm,pvc --all -n hive

```
If neccssary, delete the hanging EKS objects by setting finalizer as `null`, like this:
```bash
kubectl get svc,pvc -n hive -o yaml | grep -A 5 finalizers

kubectl patch svc <YOUR_SERVICE_NAME> -n hive -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl patch pvc <YOUR_PVC_NAME> -n hive -p '{"metadata":{"finalizers":[]}}' --type=merge
```

## Setup IRSA for EKS

The chart will create 3 service accounts without IAM role associated. Run the command to setup the IRSA. The role should allow hive to access AWS resources, such as an S3 bucket:
```bash
kubectl annotate serviceaccount -n hive --all eks.amazonaws.com/role-arn=arn:aws:iam::<ACCOUNTID>:role/<YOUR_IAM_ROLE_NAME>
```

## Update your IAM role's trust relationship in IAM console

Edit your IAM's Trust Policy and append something similar as the followings:

```json
 {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<ACCOUNTID>:oidc-provider/oidc.eks.<REIGON>.amazonaws.com/id/<YOUR_OIDC_ID>"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "oidc.eks.<REIGON>.amazonaws.com/id/<YOUR_OIDC_ID>:sub": "system:serviceaccount:hive:hive-service-account"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<ACCOUNTID>:oidc-provider/oidc.eks.<REIGON>.amazonaws.com/id/<YOUR_OIDC_ID>"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "oidc.eks.us-west-2.amazonaws.com/id/<YOUR_OIDC_ID>:sub": "system:serviceaccount:hive:master-service-account"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::<ACCOUNTID>:oidc-provider/oidc.eks.<REIGON>.amazonaws.com/id/<YOUR_OIDC_ID>"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringLike": {
                    "oidc.eks.<REIGON>.amazonaws.com/id/<YOUR_OIDC_ID>:sub": "system:serviceaccount:hive:worker-service-account"
                }
            }
        }
```

## Check the installation output on EKS

```bash
kubectl get all -n hive
```
```bash
NAME                                       READY   STATUS    RESTARTS   AGE
pod/hivemr3-hiveserver2-69fc8f8f57-qx8c9   1/1     Running   0          84m
pod/hivemr3-metastore-0                    1/1     Running   0          123m
pod/mr3master-2437-0-864949848f-f9ct2      1/1     Running   0          86m

NAME                            TYPE           CLUSTER-IP EXTERNAL-IP                                                                         PORT(S)                          AGE
service/hiveserver2             LoadBalancer   10.100.65.205   k8s-hive-hiveserv-xxx.elb.REGION.amazonaws.com,1.1.1.1   9852:31576/TCP,10001:30457/TCP   123m
service/metastore               ClusterIP      None            <none>                                                                              9850/TCP                         123m
service/service-master-2437-0   ClusterIP      10.100.77.119   <none>                                                                              80/TCP,9890/TCP                  96m
service/service-worker          ClusterIP      None            <none>                                                                              <none>                           96m

NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/hivemr3-hiveserver2   1/1     1            1           123m
deployment.apps/mr3master-2437-0      1/1     1            1           96m

NAME                                             DESIRED   CURRENT   READY   AGE
replicaset.apps/hivemr3-hiveserver2-69fc8f8f57   1         1         1       123m
replicaset.apps/mr3master-2437-0-864949848f      1         1         1       96m

NAME                                 READY   AGE
statefulset.apps/hivemr3-metastore   1/1     123m
```

## Run Beeline to validate

You may use any client program to connect to the HiveServer2. In this example, we run Beeline inside the Hiveserver2 Pod.

```bash
kubectl exec -n hive -it pod/hivemr3-hiveserver2-69fc8f8f57-6hxnf  -- bash
```
After login to the HiveServer2 pod, run beeline as Hive user:
```bash
bash-4.2$ export USER=hive
bash-4.2$ pwd
/opt/mr3-run/hive
bash-4.2$ ./run-beeline.sh
```
We create a table called pokemon.
```bash

0: jdbc:hive2://hivemr3-hiveserver2-69b7c4574> CREATE TABLE pokemon (Number Int,Name String,Type1 String,Type2 String,Total Int,HP Int,Attack Int,Defense Int,Sp_Atk Int,Sp_Def Int,Speed Int) row format delimited fields terminated BY ',' lines terminated BY '\n' tblproperties("skip.header.line.count"="1");
```
Import the sample dataset.
```bash
0: jdbc:hive2://hivemr3-hiveserver2-69b7c4574> load data local inpath '/opt/mr3-run/work-dir/pokemon.csv' INTO table pokemon;
```
Execute queries.
```bash
0: jdbc:hive2://hivemr3-hiveserver2-69b7c4574> select avg(HP) from pokemon;
+---------------------+
|         _c0         |
+---------------------+
| 144.84882280049567  |
+---------------------+
1 row selected (11.288 seconds)

0: jdbc:hive2://hivemr3-hiveserver2-69b7c4574> create table pokemon1 as select *, IF(HP>160.0,'strong',IF(HP>140.0,'moderate','weak')) AS power_rate from pokemon;

0: jdbc:hive2://hivemr3-hiveserver2-69b7c4574> select COUNT(name), power_rate from pokemon1 group by power_rate;
+------+-------------+
| _c0  | power_rate  |
+------+-------------+
| 108  | moderate    |
| 363  | strong      |
| 336  | weak        |
+------+-------------+
3 rows selected (1.144 seconds)
```
Now we see that new ContainerWorker Pods have been created.
```bash
kubectl get pods -n hive

NAME                                   READY   STATUS    RESTARTS   AGE
hivemr3-hiveserver2-69b7c45745-6wkfw   1/1     Running   0          6m45s
hivemr3-metastore-0                    1/1     Running   0          7m11s
mr3master-8633-0-768f779d-lpbq8        1/1     Running   0          6m27s
mr3worker-6c99-1                       1/1     Running   0          93s
mr3worker-6c99-2                       1/1     Running   0          35s
```