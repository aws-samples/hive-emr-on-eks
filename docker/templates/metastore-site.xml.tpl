<configuration>
  {{- if eq .Env.HIVE_DB_EXTERNAL "true" }}
  # Database Connection Properties
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:mysql://{{.Env.HIVE_DB_HOST}}:{{.Env.HIVE_DB_PORT}}/{{.Env.HIVE_DB_NAME}}?createDatabaseIfNotExist=true</value>
  </property>

  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>{{ .Env.HIVE_DB_DRIVER}}</value>
  </property>

  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>{{ .Env.HIVE_DB_USER }}</value>
  </property>

  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>{{ .Env.HIVE_DB_PASS }}</value>
  </property>
  {{- end }}

  # Metastore Configuration
  <property>
    <name>metastore.expression.proxy</name>
    <value>org.apache.hadoop.hive.metastore.DefaultPartitionExpressionProxy</value>
  </property>

  <property>
    <name>metastore.task.threads.always</name>
    <value>org.apache.hadoop.hive.metastore.events.EventCleanerTask</value>
  </property>

  <property>
    <name>hive.metastore.uris</name>
    <value>thrift:localhost:9083</value>
  </property>

  <property>
    <name>datanucleus.autoStartMechanismMode</name>
    <value>ignored</value>
  </property>

  <property>
    <name>datanucleus.autoStartMechanism</name>
    <value>SchemaTable</value>
  </property>

  <property>
    <name>datanucleus.autoCreateSchema</name>
    <value>false</value>
  </property>

  # Warehouse Directory Configuration
  {{- if not (index .Env "HIVE_WAREHOUSE_DIR") }}
  <property>
    <name>hive.metastore.warehouse.dir</name>
    <value>file:///tmp/</value>
  </property>
  {{- else }}
  {{- $hive_warehouse_dir := regexp.Replace "(.*)" "s3:\\$1" .Env.HIVE_WAREHOUSE_DIR }}
  <property>
    <name>hive.metastore.warehouse.dir</name>
    <value>{{ $hive_warehouse_dir }}</value>
  </property>
  {{- end }}

  # Additional Configuration Parameters
  {{- if (index .Env "HIVE_CONF_PARAMS") }}
  {{- $conf_list := .Env.HIVE_CONF_PARAMS | strings.Split ";" }}
  {{- range $parameter := $conf_list}}
  {{- $key := regexp.Replace "(.*):|.*" "$1" $parameter }}
  {{- $value := regexp.Replace ".*:(.*)" "$1" $parameter }}
  <property>
    <name>{{ $key }}</name>
    <value>{{ $value }}</value>
  </property>
  {{- end }}
  {{- end }}
</configuration>