aws emr-containers start-job-run \
  --virtual-cluster-id $VIRTUAL_CLUSTER_ID \
  --name sparksql-test \
  --execution-role-arn $EMR_ROLE_ARN \
  --release-label emr-6.8.0-latest \
  --job-driver '{
  "sparkSqlJobDriver": {
      "entryPoint": "s3://'$S3BUCKET'/app_code/job/set-of-hive-queries.sql",
      "sparkSqlParameters": "-hiveconf S3Bucket='$S3BUCKET' -hiveconf Key_ID=238 --conf spark.driver.cores=1 --conf spark.executor.memory=4G --conf spark.driver.memory=1G --conf spark.executor.cores=2"}}' \
  --configuration-overrides '{
    "applicationConfiguration": [
      {
        "classification": "spark-defaults", 
        "properties": {
          "spark.hive.metastore.uris": "thrift://hive-metastore:9083",
          "spark.sql.warehouse.dir": "s3://'$S3BUCKET'/warehouse/"
        }
      }
    ], 
    "monitoringConfiguration": {
      "s3MonitoringConfiguration": {"logUri": "s3://'$S3BUCKET'/elasticmapreduce/emr-containers"}}}'
