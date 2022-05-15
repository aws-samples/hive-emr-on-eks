#!/bin/bash

aws emr-containers start-job-run \
--virtual-cluster-id $VIRTUAL_CLUSTER_ID \
--name spark-hive-via-jdbc \
--execution-role-arn $EMR_ROLE_ARN \
--release-label emr-6.3.0-latest \
--job-driver '{
  "sparkSubmitJobDriver": {
      "entryPoint": "s3://'$S3BUCKET'/app_code/job/hivejdbc.py",
      "entryPointArguments":["s3://'$S3BUCKET'"],
      "sparkSubmitParameters": "--conf spark.jars.packages=mysql:mysql-connector-java:8.0.28 --conf spark.driver.cores=1 --conf spark.executor.memory=4G --conf spark.driver.memory=1G --conf spark.executor.cores=2"}}' \
--configuration-overrides '{
    "applicationConfiguration": [
      {
        "classification": "spark-defaults", 
        "properties": {
          "spark.dynamicAllocation.enabled":"false",
          "spark.hadoop.javax.jdo.option.ConnectionDriverName": "com.mysql.cj.jdbc.Driver",
          "spark.hadoop.javax.jdo.option.ConnectionUserName": "'$USER_NAME'",
          "spark.hadoop.javax.jdo.option.ConnectionPassword": "'$PASSWORD'",
          "spark.hadoop.javax.jdo.option.ConnectionURL": "jdbc:mysql://'$HOST_NAME':3306/'$DB_NAME'" 
        }
      }
    ], 
    "monitoringConfiguration": {
      "s3MonitoringConfiguration": {"logUri": "s3://'$S3BUCKET'/elasticmapreduce/emr-containers"}}}'