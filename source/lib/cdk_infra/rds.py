from aws_cdk import (RemovalPolicy, aws_ec2 as ec2, aws_rds as rds)
from constructs import Construct

class RDS_HMS(Construct):

    @property
    def secret(self):
        return self._metastore.secret

    @property
    def rds_instance(self):
        return self._metastore

    def __init__(self, scope: Construct, id: str, cluster_name: str, eksvpc: ec2.IVpc, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        self._metastore=rds.DatabaseCluster(
            self, "Aurora",
            default_database_name=cluster_name,
            engine=rds.DatabaseClusterEngine.aurora_mysql(
                version=rds.AuroraMysqlEngineVersion.VER_3_01_0
            ),
            instance_props={
                "vpc_subnets":{
                    "subnet_type": ec2.SubnetType.PRIVATE_WITH_EGRESS
                },
                "vpc": eksvpc
            },
            removal_policy=RemovalPolicy.DESTROY
        )
        # Allow EMR & EKS cluster to connect to the RDS hive metastore
        self._metastore.connections.security_groups[0].add_ingress_rule(
            peer=ec2.Peer.ipv4(eksvpc.vpc_cidr_block),
            connection=ec2.Port.tcp(3306),
            description="EMR EKS Access"
        )

