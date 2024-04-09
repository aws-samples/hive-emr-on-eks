from aws_cdk.aws_ec2 import ISecurityGroup,SubnetSelection,SubnetType
from aws_cdk import Aws, RemovalPolicy
from constructs import Construct
from aws_cdk.aws_eks import ICluster, KubernetesManifest
# import aws_cdk.aws_efs as efs
from lib.util.manifest_reader import *
import os

class EksBaseAppConst(Construct):
    def __init__(self,scope: Construct,
    id: str,
    eks_cluster: ICluster, 
    # efs_sg: ISecurityGroup, 
    **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        source_dir=os.path.split(os.environ['VIRTUAL_ENV'])[0]+'/source'
       
        # Add Cluster Autoscaler to EKS
        _var_mapping = {
            "{{region_name}}": Aws.REGION, 
            "{{cluster_name}}": eks_cluster.cluster_name, 
        }
        eks_cluster.add_helm_chart('ClusterAutoScaler',
            chart='cluster-autoscaler',
            repository='https://kubernetes.github.io/autoscaler',
            release='nodescaler',
            create_namespace=False,
            namespace='kube-system',
            values=load_yaml_replace_var_local(source_dir+'/app_resources/autoscaler-values.yaml',
                    fields=_var_mapping
                )
        )

        # Add k8s metric server for horizontal pod autoscaler (HPA)
        KubernetesManifest(self,'MetricsSrv',
            cluster=eks_cluster, 
            manifest=load_yaml_remotely('https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml', 
                    multi_resource=True
            )
        )
        # Add external secrets controller to EKS
        eks_cluster.add_helm_chart('SecretContrChart',
            chart='kubernetes-external-secrets',
            repository='https://external-secrets.github.io/kubernetes-external-secrets/',
            release='external-secrets',
            create_namespace=False,
            namespace='kube-system',
            values=load_yaml_replace_var_local(source_dir+'/app_resources/ex-secret-values.yaml',
                fields={
                    "{{region_name}}": Aws.REGION
                }
            )
        )

        # # Add Spark Operator to EKS
        # eks_cluster.add_helm_chart('SparkOperatorChart',
        #     chart='spark-operator',
        #     repository='https://kubeflow.github.io/spark-operator',
        #     release='spark-operator',
        #     version='1.1.27',
        #     create_namespace=True,
        #     values=load_yaml_replace_var_local(source_dir+'/app_resources/spark-operator-values.yaml',fields={'':''})
        # )

        #  # Add EFS persistent storage to EKS across AZs
        # eks_cluster.add_helm_chart('EFSDriver', 
        #     chart='aws-efs-csi-driver',
        #     release='efs-driver',
        #     repository='https://kubernetes-sigs.github.io/aws-efs-csi-driver/',
        #     create_namespace=False,
        #     namespace='kube-system',
        # )
        # _k8s_efs = efs.FileSystem(self,'EFSFileSystem',
        #     vpc=eks_cluster.vpc,
        #     security_group=efs_sg,
        #     encrypted=True,
        #     lifecycle_policy=efs.LifecyclePolicy.AFTER_7_DAYS,
        #     performance_mode=efs.PerformanceMode.MAX_IO,
        #     removal_policy=RemovalPolicy.DESTROY,
        #     vpc_subnets=SubnetSelection(subnet_type=SubnetType.PRIVATE_WITH_EGRESS, one_per_az=True)
        # )
        # _pv= KubernetesManifest(self,'pvClaim',
        #     cluster=eks_cluster,
        #     manifest=load_yaml_replace_var_local(source_dir+'/app_resources/efs-spec.yaml', 
        #         fields= {
        #             "{{FileSystemId}} ": _k8s_efs.file_system_id
        #         },
        #         multi_resource=True)
        # )      
        # _pv.node.add_dependency(_k8s_efs)
