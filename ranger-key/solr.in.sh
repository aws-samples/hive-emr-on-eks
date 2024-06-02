SOLR_JAVA_HOME=$JAVA_HOME

SOLR_JAVA_MEM="-Xms2g -Xmx2g"

GC_LOG_OPTS="-verbose:gc"

GC_TUNE="-XX:NewRatio=3 \
-XX:SurvivorRatio=4 \
-XX:TargetSurvivorRatio=90 \
-XX:MaxTenuringThreshold=8 \
-XX:+UseConcMarkSweepGC \
-XX:+UseParNewGC \
-XX:ConcGCThreads=4 -XX:ParallelGCThreads=4 \
-XX:+CMSScavengeBeforeRemark \
-XX:PretenureSizeThreshold=64m \
-XX:+UseCMSInitiatingOccupancyOnly \
-XX:CMSInitiatingOccupancyFraction=50 \
-XX:CMSMaxAbortablePrecleanTime=6000 \
-XX:+CMSParallelRemarkEnabled \
-XX:+ParallelRefProcEnabled"

ENABLE_REMOTE_JMX_OPTS="false"

SOLR_HOME=/opt/mr3-run/ranger/solr/ranger_audit_server

SOLR_DATA_HOME=/opt/mr3-run/ranger/work-dir/ranger/solr/ranger_audits/data

LOG4J_PROPS=$SOLR_HOME/resources/log4j2.xml

#SOLR_LOG_LEVEL=INFO

SOLR_LOGS_DIR=/opt/mr3-run/ranger/work-dir/log/solr/ranger_audits

SOLR_HOST=
SOLR_PORT=6083

#SOLR_SSL_ENABLED=false

SOLR_SSL_ENABLED=true
SOLR_SSL_KEY_STORE=/opt/mr3-run/ranger/key/hivemr3-ssl-certificate.jks
SOLR_SSL_KEY_STORE_PASSWORD=80d4163f-9798-4786-938a-50dadf7c86af
SOLR_SSL_TRUST_STORE=/opt/mr3-run/ranger/key/hivemr3-ssl-certificate.jks
SOLR_SSL_TRUST_STORE_PASSWORD=80d4163f-9798-4786-938a-50dadf7c86af
SOLR_SSL_NEED_CLIENT_AUTH=false
SOLR_SSL_WANT_CLIENT_AUTH=false
SOLR_SSL_CHECK_PEER_NAME=true
SOLR_SSL_KEY_STORE_TYPE=JKS
SOLR_SSL_TRUST_STORE_TYPE=JKS

#SOLR_AUTH_TYPE="basic"
#SOLR_AUTHENTICATION_OPTS="-Dbasicauth=solr:solrRocks"

SOLR_AUTH_TYPE="kerberos"
SOLR_AUTHENTICATION_OPTS="\
-Djava.security.krb5.conf=/opt/mr3-run/ranger/conf/krb5.conf \
-Dsolr.kerberos.cookie.domain=red0 \
-Dsolr.kerberos.principal=HTTP/red0@RED \
-Dsolr.kerberos.keytab=/opt/mr3-run/ranger/key/spnego.service.keytab"

SOLR_OPTS="$SOLR_OPTS -Dlog4j2.formatMsgNoLookups=true"

