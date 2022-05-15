from aws_cdk import (Tags, Aws, RemovalPolicy, aws_iam as iam)
from constructs import Construct

class IamConst(Construct):

    @property
    def managed_node_role(self):
        return self._managed_node_role

    @property
    def admin_role(self):
        return self._clusterAdminRole 

    @property
    def emr_svc_role(self):
        return self._emrsvcrole 

    def __init__(self,scope: Construct, id:str, cluster_name:str, **kwargs,) -> None:
        super().__init__(scope, id, **kwargs)

        # EKS admin role
        self._clusterAdminRole = iam.Role(self, 'ClusterAdmin',
            assumed_by= iam.AccountRootPrincipal()
        )
        self._clusterAdminRole.add_to_policy(iam.PolicyStatement(
            resources=["*"],
            actions=[
                "eks:Describe*",
                "eks:List*",
                "eks:AccessKubernetesApi",
                "ssm:GetParameter",
                "iam:ListRoles"
            ],
        ))
        Tags.of(self._clusterAdminRole).add(
            key='eks/%s/type' % cluster_name, 
            value='admin-role'
        )

        # Managed Node Group Instance Role
        _managed_node_managed_policies = (
            iam.ManagedPolicy.from_aws_managed_policy_name('AmazonEKSWorkerNodePolicy'),
            iam.ManagedPolicy.from_aws_managed_policy_name('AmazonEKS_CNI_Policy'),
            iam.ManagedPolicy.from_aws_managed_policy_name('AmazonEC2ContainerRegistryReadOnly'),
            iam.ManagedPolicy.from_aws_managed_policy_name('CloudWatchAgentServerPolicy'), 
            iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMManagedInstanceCore'), 
        )
        self._managed_node_role = iam.Role(self,'NodeInstanceRole',
            path='/',
            assumed_by=iam.ServicePrincipal('ec2.amazonaws.com'),
            managed_policies=list(_managed_node_managed_policies),
        )
        self._managed_node_role.apply_removal_policy(RemovalPolicy.DESTROY)

        # EMR container service role
        self._emrsvcrole = iam.Role.from_role_arn(self, "EmrSvcRole", 
            role_arn=f"arn:aws:iam::{Aws.ACCOUNT_ID}:role/AWSServiceRoleForAmazonEMRContainers", 
            mutable=False
        )