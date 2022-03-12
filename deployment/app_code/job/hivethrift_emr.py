    # .config("spark.sql.warehouse.dir", sys.argv[1]+"/warehouse/" ) \
    # from os import environ
import sys
from pyspark.sql import SparkSession
spark = SparkSession \
    .builder \
    .config("hive.metastore.uris","thrift://"+sys.argv[2]+":9083") \
    .enableHiveSupport() \
    .getOrCreate()
spark.sql("SHOW DATABASES").show()
spark.sql("CREATE DATABASE IF NOT EXISTS `demo`")
spark.sql("DROP TABLE IF EXISTS `demo`.`amazonreview2`")
spark.sql("CREATE EXTERNAL TABLE `demo`.`amazonreview2`( `marketplace` string,`customer_id`string,`review_id` string,`product_id` string,`product_parent` string,`product_title` string,`star_rating` integer,`helpful_votes` integer,`total_votes` integer,`vine` string,`verified_purchase` string,`review_headline` string,`review_body` string,`review_date` date,`year` integer) STORED AS PARQUET LOCATION '"+sys.argv[1]+"/app_code/data/toy/'")
spark.sql("SELECT count(*) FROM `demo`.`amazonreview2`").show()
spark.stop()