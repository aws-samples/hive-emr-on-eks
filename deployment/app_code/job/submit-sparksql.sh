# "spark.hive.metastore.uris": "thrift://hive-metastore:9083"
aws emr-containers start-job-run \
  --virtual-cluster-id $VIRTUAL_CLUSTER_ID \
  --name sparksql-test \
  --execution-role-arn $EMR_ROLE_ARN \
  --release-label emr-6.8.0-latest \
  --job-driver '{
  "sparkSqlJobDriver": {
      "entryPoint": "s3://'$S3BUCKET'/app_code/job/set-of-hive-queries.sql",
      "sparkSqlParameters": "-hivevar S3Bucket='$S3BUCKET' -hivevar Key_ID=238"}}' \
  --configuration-overrides '{
    "applicationConfiguration": [
      {
        "classification": "spark-defaults", 
        "properties": {
          "spark.hadoop.hive.metastore.client.factory.class": "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
        }
      }
    ], 
    "monitoringConfiguration": {
      "s3MonitoringConfiguration": {"logUri": "s3://'$S3BUCKET'/elasticmapreduce/emr-containers"}}}'
