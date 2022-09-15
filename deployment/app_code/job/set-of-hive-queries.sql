CREATE DATABASE IF NOT EXISTS hiveonspark;
USE hiveonspark;

--create hive managed table
DROP TABLE IF EXISTS testtable purge;
CREATE TABLE IF NOT EXISTS testtable (`key` INT, `value` STRING) using hive;
LOAD DATA LOCAL INPATH '/usr/lib/spark/examples/src/main/resources/kv1.txt' INTO TABLE testtable;
SELECT * FROM testtable WHERE key=238;

-- test1: add column
ALTER TABLE testtable ADD COLUMNS (`arrayCol` Array<int>);
INSERT INTO testtable VALUES 
(238,'val_238',array(1,3)),
(238,'val_238',array(2,3));
-- test2: insert
SELECT * FROM testtable WHERE key=238;
-- test3: UDF
CREATE TEMPORARY FUNCTION hiveUDF AS 'org.apache.hadoop.hive.ql.udf.generic.GenericUDTFExplode';
SELECT `key`,`value`,hiveUDF(arrayCol) FROM testtable WHERE key=238;

--Hive external table mapped to S3 data
DROP TABLE IF EXISTS amazonreview;
CREATE EXTERNAL TABLE IF NOT EXISTS amazonreview( marketplace string, customer_id string, review_id  string, product_id  string, product_parent  string, product_title  string, star_rating  integer, helpful_votes  integer, total_votes  integer, vine  string, verified_purchase  string, review_headline  string, review_body  string, review_date  date, year  integer) STORED AS PARQUET LOCATION 's3://<<S3BUCKET>>/app_code/data/toy/';
SELECT count(*) FROM amazonreview;
