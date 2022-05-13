from aws_cdk import (
    core,
    aws_iam as iam,
    aws_emrcontainers as emrc
)
from aws_cdk.aws_eks import ICluster, KubernetesManifest
from lib.util.manifest_reader import load_yaml_replace_var_local
import os

class AppSecConst(core.Construct):

    @property
    def EMRVC(self):
        return self.emr_vc.attr_id

    @property
    def EMRExecRole(self):
        return self._emr_exec_role.role_arn 

    def __init__(self,scope: core.Construct, id: str, 
        eks_cluster: ICluster, 
        code_bucket: str,
        **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        source_dir=os.path.split(os.environ['VIRTUAL_ENV'])[0]+'/source'  
   
# //*****************************************************************************************//
# //***************************** SETUP PERMISSION FOR SPARK  *******************************//
# //******* create k8s namespace, service account, and IAM role for service account ********//
# //***************************************************************************************//

        #################################
        #######                   #######
        #######   EMR Namespace   #######
        #######                   #######
        #################################
        _emr_01_name = "emr"
        emr_ns = eks_cluster.add_manifest('EMRNamespace',{
                "apiVersion": "v1",
                "kind": "Namespace",
                "metadata": { 
                    "name":  _emr_01_name,
                    "labels": {"name": _emr_01_name}
                }
            }
        )

        #######################################
        #######                         #######
        #######   k8s Service Account   #######
        #######                         #######
        #######################################
        _hive_sa = eks_cluster.add_service_account('HiveSA', 
            name='hive', 
            namespace=_emr_01_name
        )
        _hive_sa.node.add_dependency(emr_ns)

        ###########################################
        #######                             #######
        #######   k8s rbac for EMR on EKS   #######
        #######                             #######
        ###########################################
        _emr_rb = KubernetesManifest(self,'EMRRoleBinding',
            cluster=eks_cluster,
            manifest=load_yaml_replace_var_local(source_dir+'/app_resources/emr-rbac.yaml', 
            fields= {
                "{{NAMESPACE}}": _emr_01_name,
            }, 
            multi_resource=True)
        )
        _emr_rb.node.add_dependency(emr_ns)

        _hive_rb = KubernetesManifest(self,'HIVERoleBinding',
            cluster=eks_cluster,
            manifest=load_yaml_replace_var_local(source_dir+'/app_resources/hive-rbac.yaml', 
            fields= {
                "{{NAMESPACE}}": _emr_01_name,
                "{{ServiceAccount}}": "hive"
            }, 
            multi_resource=True)
        )
        _hive_rb.node.add_dependency(_hive_sa)

        # Create EMR on EKS job executor role
        #######################################
        #######                         #######
        #######   EMR Execution Role    #######
        #######                         #######
        #######################################
        self._emr_exec_role = iam.Role(self, "EMRJobExecRole", assumed_by=iam.ServicePrincipal("eks.amazonaws.com"))
        
        # trust policy
        _eks_oidc_provider=eks_cluster.open_id_connect_provider 
        _eks_oidc_issuer=_eks_oidc_provider.open_id_connect_provider_issuer 
         
        sub_str_like = core.CfnJson(self, "ConditionJsonIssuer",
            value={
                f"{_eks_oidc_issuer}:sub": f"system:serviceaccount:{_emr_01_name}:emr-containers-sa-*-*-{core.Aws.ACCOUNT_ID}-*"
            }
        )
        self._emr_exec_role.assume_role_policy.add_statements(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=["sts:AssumeRoleWithWebIdentity"],
                principals=[iam.OpenIdConnectPrincipal(_eks_oidc_provider, conditions={"StringLike": sub_str_like})])
        )

        aud_str_like = core.CfnJson(self,"ConditionJsonAudEMR",
            value={
                f"{_eks_oidc_issuer}:aud": "sts.amazon.com"
            }
        )
        self._emr_exec_role.assume_role_policy.add_statements(
            iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                actions=["sts:AssumeRoleWithWebIdentity"],
                principals=[iam.OpenIdConnectPrincipal(_eks_oidc_provider, conditions={"StringEquals": aud_str_like})]
            )
        )

        # Associate AWS IAM role to K8s Service Account
        ###################################################
        #######                                     #######
        #######    IAM Roles for Service Accounts   #######
        #######                                     #######
        ###################################################
        _emr_iam = load_yaml_replace_var_local(source_dir+'/app_resources/emr-iam-role.yaml',
            fields={
                 "{{codeBucket}}": code_bucket,
                 "{{AWS_REGION}}": core.Aws.REGION,
                 "{{ACCOUNT}}": core.Aws.ACCOUNT_ID
            }
        )
        for statmnt in _emr_iam:
            self._emr_exec_role.add_to_policy(iam.PolicyStatement.from_json(statmnt))
            _hive_sa.add_to_principal_policy(iam.PolicyStatement.from_json(statmnt))

        ############################################
        #######                              #######
        #######  EMR virtual Cluster Server  #######
        #######                              #######
        ############################################
        self.emr_vc = emrc.CfnVirtualCluster(self,"EMRVC",
            container_provider=emrc.CfnVirtualCluster.ContainerProviderProperty(
                id=eks_cluster.cluster_name,
                info=emrc.CfnVirtualCluster.ContainerInfoProperty(eks_info=emrc.CfnVirtualCluster.EksInfoProperty(namespace=_emr_01_name)),
                type="EKS"
            ),
            name="HiveDemo"
        )
        self.emr_vc.node.add_dependency(self._emr_exec_role)
        self.emr_vc.node.add_dependency(_emr_rb)