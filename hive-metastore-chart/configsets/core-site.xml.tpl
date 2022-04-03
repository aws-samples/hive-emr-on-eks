<configuration>
  {{- if index .Env  "HIVE_WAREHOUSE_S3LOCATION"  }}
  <property>
    <name>fs.defaultFS</name>
    <value>{{ .Env.HIVE_WAREHOUSE_S3LOCATION }}</value>
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
      <value>com.amazonaws.auth.DefaultAWSCredentialsProviderChain</value>
  </property>
</configuration>
