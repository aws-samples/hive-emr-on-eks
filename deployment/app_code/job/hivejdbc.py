import sys
from pyspark.sql import SparkSession
spark = SparkSession \
    .builder \
    .config("spark.sql.warehouse.dir", sys.argv[1]+"/warehouse/" ) \
    .enableHiveSupport() \
    .getOrCreate()
spark.sql("SHOW DATABASES").show()
spark.sql("CREATE DATABASE IF NOT EXISTS `demo`")
spark.sql("CREATE EXTERNAL TABLE IF NOT EXISTS `demo`.`amazonreview`( `marketplace` string,`customer_id`string,`review_id` string,`product_id` string,`product_title` string,`star_rating` integer,`helpful_votes` integer,`total_votes` integer,`insight` string,`review_headline` string,`review_body` string,`review_date` timestamp,`year` integer) STORED AS PARQUET LOCATION '"+sys.argv[1]+"/app_code/data/toy/'")
spark.sql("SELECT count(*) FROM demo.amazonreview").show()
spark.stop()