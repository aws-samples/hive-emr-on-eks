# Run Hive metastore and Hive Server2 in EKS

This is a project containing multiple helm chart for Hive releated components.
Make sure you are in the correct branch

```bash
git clone -b hs2-hms git@github.com:aws-samples/hive-emr-on-eks.git
```

## Install the hive helm chart

```bash
kubectl create ns hive
helm install hive helm/hive -f values-hive.yaml --namespace hive --debug
```

The chart will create 3 service accounts without IAM role associated. Run the command to setup the IRSA. The role should allow hive to access AWS resources, such as an S3 bucket:
```bash

kubectl annotate serviceaccount -n hive --all eks.amazonaws.com/role-arn=arn:aws:iam::021732063925:role/<YOUR_IAM_ROLE_NAME>

```

## Update your IAM role's trust relationship

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


NAME                                       READY   STATUS    RESTARTS   AGE
pod/hivemr3-hiveserver2-69fc8f8f57-qx8c9   1/1     Running   0          84m
pod/hivemr3-metastore-0                    1/1     Running   0          123m
pod/mr3master-2437-0-864949848f-f9ct2      1/1     Running   0          86m

NAME                            TYPE           CLUSTER-IP      EXTERNAL-IP                                                                         PORT(S)                          AGE
service/hiveserver2             LoadBalancer   10.100.65.205   k8s-hive-hiveserv-00fae1623a-4e828818a4aede01.elb.us-west-2.amazonaws.com,1.1.1.1   9852:31576/TCP,10001:30457/TCP   123m
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
