<configuration>
  {{- if index .Env "HIVE_WAREHOUSE_S3LOCATION" }}
  <property>
    <name>fs.defaultFS</name>
    <value>s3://{{ .Env.HIVE_WAREHOUSE_S3LOCATION }}</value>
  </property>
  {{- end }}

  <property>
    <name>fs.s3a.impl</name>
    <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value>
  </property>

  <property>
    <name>fs.s3.impl</name>
    <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value>
  </property>

  <property>
    <name>fs.s3n.impl</name>
    <value>org.apache.hadoop.fs.s3a.S3AFileSystem</value>
  </property>

  <property>
    <name>fs.s3a.aws.credentials.provider</name>
    <value>
      {{ if eq (env.Getenv "AWS_SDK_VERSION") "1" }}
        {{ env.Getenv "HIVE_CREDENTIALS_PROVIDER" "com.amazonaws.auth.DefaultAWSCredentialsProviderChain" }}
      {{ else if eq (env.Getenv "AWS_SDK_VERSION") "2" }}
        {{ env.Getenv "HIVE_CREDENTIALS_PROVIDER" "software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider" }}
      {{ end }}
    </value>
  </property>
</configuration>