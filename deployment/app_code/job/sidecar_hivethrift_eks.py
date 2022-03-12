import sys
from pyspark.sql import SparkSession

spark = SparkSession \
    .builder \
    .config("spark.sql.warehouse.dir", sys.argv[1]+"/warehouse/" ) \
    .enableHiveSupport() \
    .getOrCreate()

spark.sql("SHOW DATABASES").show()
spark.sql("CREATE DATABASE IF NOT EXISTS `demo`")
spark.sql("DROP TABLE IF EXISTS demo.amazonreview4")
spark.sql("CREATE EXTERNAL TABLE `demo`.`amazonreview4`( `marketplace` string,`customer_id`string,`review_id` string,`product_id` string,`product_parent` string,`product_title` string,`star_rating` integer,`helpful_votes` integer,`total_votes` integer,`vine` string,`verified_purchase` string,`review_headline` string,`review_body` string,`review_date` date,`year` integer) STORED AS PARQUET LOCATION '"+sys.argv[1]+"/app_code/data/toy/'")

# read from files
# TODO: make it a UDF
sql_scripts=spark.read.text(sys.argv[1]+"/app_code/job/set-of-hive-queries.sql").collect()
cmd_str=' '.join([x[0] for x in sql_scripts]).split(';')
for query in cmd_str:
    if (query != ""):
        spark.sql(query).show()
spark.stop()