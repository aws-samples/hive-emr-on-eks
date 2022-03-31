#!/bin/bash
# test HMS on EKS
aws emr-containers start-job-run \
--virtual-cluster-id $VIRTUAL_CLUSTER_ID \
--name spark-hive-via-thrift-EKS \
--execution-role-arn $EMR_ROLE_ARN \
--release-label emr-6.5.0-latest \
--job-driver '{
  "sparkSubmitJobDriver": {
      "entryPoint": "s3://'$S3BUCKET'/app_code/job/hivethrift_eks.py",
      "entryPointArguments":["s3://'$S3BUCKET'"],
      "sparkSubmitParameters": "--conf spark.driver.cores=1 --conf spark.executor.memory=4G --conf spark.driver.memory=1G --conf spark.executor.cores=2"}}' \
--configuration-overrides '{
    "monitoringConfiguration": {
      "s3MonitoringConfiguration": {"logUri": "s3://'$S3BUCKET'/elasticmapreduce/emr-containers"}}}'
