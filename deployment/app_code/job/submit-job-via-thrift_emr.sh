#!/bin/bash
# reuse HMS on EMR on EC2
export STACK_NAME=HiveEMRonEKS
export EMR_MASTER_DNS_NAME=$(aws ec2 describe-instances --filter Name=tag:project,Values=$STACK_NAME Name=tag:aws:elasticmapreduce:instance-group-role,Values=MASTER --query Reservations[].Instances[].PrivateDnsName --output text | xargs) 

aws emr-containers start-job-run \
--virtual-cluster-id $VIRTUAL_CLUSTER_ID \
--name spark-hive-via-thrift-EMR \
--execution-role-arn $EMR_ROLE_ARN \
--release-label emr-6.3.0-latest \
--job-driver '{
  "sparkSubmitJobDriver": {
      "entryPoint": "s3://'$S3BUCKET'/app_code/job/hivethrift_emr.py",
      "entryPointArguments":["s3://'$S3BUCKET'","'$EMR_MASTER_DNS_NAME'"],
      "sparkSubmitParameters": "--conf spark.driver.cores=1 --conf spark.executor.memory=4G --conf spark.driver.memory=1G --conf spark.executor.cores=2"}}' \
--configuration-overrides '{
    "monitoringConfiguration": {
      "s3MonitoringConfiguration": {"logUri": "s3://'$S3BUCKET'/elasticmapreduce/emr-containers"}}}'
