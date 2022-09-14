CREATE DATABASE IF NOT EXISTS hiveonspark;
CREATE TABLE IF NOT EXISTS hiveonspark.amazonreview( marketplace string, customer_id string, review_id  string, product_id  string, product_parent  string, product_title  string, star_rating  integer, helpful_votes  integer, total_votes  integer, vine  string, verified_purchase  string, review_headline  string, review_body  string, review_date  date, year  integer) STORED AS PARQUET LOCATION 's3://<S3BUCKET>/app_code/data/toy/';
SELECT count(*) FROM hiveonspark.amazonreview;
SELECT count(*) FROM hiveonspark.amazonreview WHERE star_rating = 3;
SELECT distinct star_rating FROM hiveonspark.amazonreview;