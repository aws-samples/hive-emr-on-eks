from aws_cdk import core, aws_eks as eks
from aws_cdk.aws_iam import PolicyStatement

from lib.cdk_infra.iam_roles import IamConst 
from lib.cdk_infra.network_sg import NetworkSgConst
from lib.cdk_infra.iam_roles import IamConst
from lib.cdk_infra.eks_cluster import EksConst
from lib.cdk_infra.eks_service_account import EksSAConst
from lib.cdk_infra.eks_base_app import EksBaseAppConst
from lib.cdk_infra.s3_app_code import S3AppCodeConst
from lib.cdk_infra.spark_permission import AppSecConst
from lib.cdk_infra.rds import RDS_HMS

from lib.util.manifest_reader import load_yaml_replace_var_local
from os import path,environ

class SparkOnEksStack(core.Stack):

    @property
    def code_bucket(self):
        return self._app_s3.code_bucket

    @property
    def eks_cluster(self):
        return self._eks_cluster.my_cluster

    @property
    def rds_secret(self):
        return self._rds_hms.secret  

    @property
    def EMRVC(self):
        return self._emr_sec.EMRVC

    @property
    def EMRExecRole(self):
        return self._emr_sec.EMRExecRole        
        
    def __init__(self, scope: core.Construct, id: str, eksname: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # 1. a new bucket to store application code
        self._app_s3 = S3AppCodeConst(self,'appcode')

        # 2. EKS base infra
        _network_sg = NetworkSgConst(self,'network-sg', eksname)
        _iam = IamConst(self,'iam_roles', eksname)
        self._eks_cluster = EksConst(self,'eks_cluster', eksname, _network_sg.vpc, _iam.managed_node_role, _iam.admin_role, _iam.emr_svc_role)
        # OPTIONAL: comment out if you have an exiting Hive Metastore
        self._rds_hms = RDS_HMS(self,'RDS', eksname, _network_sg.vpc)
        EksSAConst(self, 'eks_service_account', self._eks_cluster.my_cluster,self._rds_hms.secret)
        EksBaseAppConst(self, 'eks_base_app', self._eks_cluster.my_cluster)
        # EksBaseAppConst(self, 'eks_base_app', self._eks_cluster.my_cluster, _network_sg.efs_sg)
        
        # 3. Setup Spark environment, Register for EMR on EKS
        self._emr_sec = AppSecConst(self,'spark_permission',self._eks_cluster.my_cluster, self._app_s3.code_bucket)

        
        # 4. Install Hive metastore chart to EKS
        _secret_name ="rds-hms-secret"
        _rds_endpoint=self._rds_hms.rds_instance.cluster_endpoint
        source_dir=path.split(environ['VIRTUAL_ENV'])[0]+'/source'

        _hms_chart = self._eks_cluster.my_cluster.add_helm_chart('HMSChart',
            chart='hive-metastore',
            repository='https://aws-samples.github.io/hive-metastore-chart',
            release='hive',
            version='1.2.0',
            create_namespace=False,
            namespace='emr',
            values=load_yaml_replace_var_local(source_dir+'/app_resources/hive-metastore-values.yaml',
                fields={
                    "{{RDS_JDBC_URL}}": f"jdbc:mysql://{_rds_endpoint.socket_address}/{eksname}?createDatabaseIfNotExist=true",
                    "{{RDS_HOSTNAME}}": _rds_endpoint.hostname,
                    "{{S3BUCKET}}": f"s3://{self._app_s3.code_bucket}"
                }
            )
        )
        _hms_chart.node.add_dependency(self._emr_sec)

        # get HMS credential from secrets manager
        _config_hms = eks.KubernetesManifest(self,'HMSConfig',
            cluster=self._eks_cluster.my_cluster,
            manifest=load_yaml_replace_var_local(source_dir+'/app_resources/hive-metastore-config.yaml', 
                fields= {
                    "{SECRET_MANAGER_NAME}": self._rds_hms.secret.secret_name
                },
                multi_resource=True
            )
        )
        _config_hms.node.add_dependency(_hms_chart)

        # 5. temp FIX: Hive standalone metastore doesn't support IRSA yet. Use EKS node IAM role instead
        _source_dir=path.split(environ['VIRTUAL_ENV'])[0]+'/source'
        _node_iam = load_yaml_replace_var_local(_source_dir+'/app_resources/emr-iam-role.yaml', 
            fields= {
                "{{codeBucket}}": self._app_s3.code_bucket
            })
        for statmnt in _node_iam:
            _iam.managed_node_role.add_to_policy(PolicyStatement.from_json(statmnt)
        )