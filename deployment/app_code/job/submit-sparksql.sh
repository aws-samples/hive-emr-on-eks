# -hiveconf mybuclet='$S3BUCKET' 
aws emr-containers start-job-run \
--virtual-cluster-id $VIRTUAL_CLUSTER_ID \
--name sparksql-test \
--execution-role-arn $EMR_ROLE_ARN \
--release-label emr-6.8.0-latest \
--job-driver '{
  "sparkSqlJobDriver": {
      "entryPoint": "s3://'$S3BUCKET'/app_code/job/set-of-hive-queries.sql",
      "sparkSqlParameters": "--conf spark.driver.cores=1 --conf spark.executor.memory=4G --conf spark.driver.memory=1G --conf spark.executor.cores=2"}}' \
--configuration-overrides '{
    "applicationConfiguration": [
      {
        "classification": "spark-defaults", 
        "properties": {
          "spark.hive.metastore.uris": "thrift://hive-metastore:9083"
        }
      }
    ], 
    "monitoringConfiguration": {
      "persistentAppUI": "ENABLED",
      "s3MonitoringConfiguration": {"logUri": "s3://'$S3BUCKET'/elasticmapreduce/emr-containers"}}}'