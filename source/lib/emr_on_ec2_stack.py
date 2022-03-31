from aws_cdk import (
    core, 
    aws_iam as iam,
    aws_ec2 as ec2,
    aws_eks as eks

)
from aws_cdk.aws_emr import CfnCluster
from aws_cdk.aws_secretsmanager import Secret
from lib.util.manifest_reader import load_yaml_replace_var_local
import os

class EMREC2Stack(core.NestedStack):

    def __init__(self, scope: core.Construct, id: str, emr_version: str, eks_cluster: eks.ICluster, code_bucket:str, rds_secret: Secret, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        source_dir=os.path.split(os.environ['VIRTUAL_ENV'])[0]+'/source'
        # The VPC requires a Tag to allow EMR to create the relevant security groups
        core.Tags.of(eks_cluster.vpc).add("for-use-with-amazon-emr-managed-policies", "true")   

        ##########################
        ######             #######
        ######  EMR Roles  #######
        ######             #######
        ##########################
        emr_job_role = iam.Role(self,"EMRJobRole",
            assumed_by=iam.ServicePrincipal("ec2.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AmazonElasticMapReduceforEC2Role"),
                iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSSMManagedInstanceCore')
            ]
        )
        _iam = load_yaml_replace_var_local(source_dir+'/app_resources/emr-iam-role.yaml', 
            fields= {
                "{{codeBucket}}": code_bucket
            })
        for statmnt in _iam:
            emr_job_role.add_to_policy(iam.PolicyStatement.from_json(statmnt)
        )

        # emr service role
        svc_role = iam.Role(self,"EMRSVCRole",
            assumed_by=iam.ServicePrincipal("elasticmapreduce.amazonaws.com"),
            managed_policies=[
                iam.ManagedPolicy.from_aws_managed_policy_name("service-role/AmazonEMRServicePolicy_v2")
            ]
        )
        svc_role.add_to_policy(iam.PolicyStatement(
                actions=["iam:PassRole"],
                resources=[emr_job_role.role_arn],
                conditions={"StringEquals": {"iam:PassedToService": "ec2.amazonaws.com"}})
        )
        svc_role.add_to_policy(iam.PolicyStatement(
                effect=iam.Effect.ALLOW,
                resources=["*"],
                actions=["ec2:RunInstances"])
        )

        # emr job flow profile
        emr_job_flow_profile = iam.CfnInstanceProfile(self,"EMRJobflowProfile",
            roles=[emr_job_role.role_name],
            instance_profile_name=emr_job_role.role_name
        )
        ####################################
        #######                      #######
        #######  EMR Master Node SG  #######
        #######                      #######
        ####################################
        self._thrift_sg = ec2.SecurityGroup(self,'thrift',
            security_group_name=eks_cluster.cluster_name + '-thrift-sg',
            vpc=eks_cluster.vpc,
            description='Hive thrift server incoming'
        )
        self._thrift_sg.add_ingress_rule(ec2.Peer.ipv4(eks_cluster.vpc.vpc_cidr_block),ec2.Port.tcp(port=9083), "connect to hive thrift from EKS")

        ####################################
        #######                      #######
        #######  Create EMR Cluster  #######
        #######                      #######
        ####################################
        
        # Database configuration variables
        rds_hostname = rds_secret.secret_value_from_json("host").to_string()
        rds_port = rds_secret.secret_value_from_json("port").to_string()
        rds_dbname = rds_secret.secret_value_from_json("dbname").to_string()
        rds_username=rds_secret.secret_value_from_json("username").to_string()
        rds_pwd=rds_secret.secret_value_from_json("password").to_string()

        self._emr_c = CfnCluster(self,"emr_ec2_cluster",
            name=eks_cluster.cluster_name,
            applications=[CfnCluster.ApplicationProperty(name="Hive")],
            log_uri=f"s3://{code_bucket}/elasticmapreduce/",
            release_label=emr_version,
            visible_to_all_users=True,
            service_role=svc_role.role_name,
            job_flow_role=emr_job_role.role_name,
            instances=CfnCluster.JobFlowInstancesConfigProperty(
                # ec2_key_name=key_name,
                termination_protected=False,
                master_instance_group=CfnCluster.InstanceGroupConfigProperty(
                    instance_count=1, 
                    instance_type="m5.xlarge"
                ),
                additional_master_security_groups=[self._thrift_sg.security_group_id],
                core_instance_group=CfnCluster.InstanceGroupConfigProperty(
                    instance_count=1, 
                    instance_type="m5.xlarge"
                ),
                ec2_subnet_id=eks_cluster.vpc.private_subnets[0].subnet_id
            ),
            configurations=[
                CfnCluster.ConfigurationProperty(
                    classification="hive-site",
                    configuration_properties={
                        "javax.jdo.option.ConnectionURL":f"jdbc:mysql://{rds_hostname}:{rds_port}/{rds_dbname}?createDatabaseIfNotExist=true",
                        "javax.jdo.option.ConnectionDriverName": "com.mysql.cj.jdbc.Driver",
                        "javax.jdo.option.ConnectionUserName": rds_username,
                        "javax.jdo.option.ConnectionPassword": rds_pwd
                    },
                )
            ],
            tags=[
                core.CfnTag(key="for-use-with-amazon-emr-managed-policies", value="true"),
                core.CfnTag(key="project", value=eks_cluster.cluster_name)
            ]
        )
        self._emr_c.add_depends_on(emr_job_flow_profile)
     