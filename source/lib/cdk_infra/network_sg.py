from aws_cdk import (
    core,
    aws_ec2 as ec2
)

class NetworkSgConst(core.Construct):

    @property
    def vpc(self):
        return self._vpc

    @property
    def efs_sg(self):
        return self._eks_efs_sg    

    def __init__(self,scope: core.Construct, id:str, eksname:str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)
        
        # //*************************************************//
        # //******************* NETWORK ********************//
        # //************************************************//
        # create VPC
        self._vpc = ec2.Vpc(self, 'eksVpc',max_azs=2, nat_gateways=1)
        core.Tags.of(self._vpc).add('Name', eksname + 'EksVpc')

        # VPC endpoint security group
        self._vpc_endpoint_sg = ec2.SecurityGroup(self,'EndpointSg',
            vpc=self._vpc,
            description='Security Group for Endpoint',
        )
        self._vpc_endpoint_sg.add_ingress_rule(ec2.Peer.ipv4(self._vpc.vpc_cidr_block),ec2.Port.tcp(port=443))
        core.Tags.of(self._vpc_endpoint_sg).add('Name','EMROnEKS-VPCEndpointSg')
        
        # Add VPC endpoint 
        self._vpc.add_gateway_endpoint("S3GatewayEndpoint",
                                        service=ec2.GatewayVpcEndpointAwsService.S3,
                                        subnets=[ec2.SubnetSelection(subnet_type=ec2.SubnetType.PUBLIC),
                                                 ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE)])
                                                 
        self._vpc.add_interface_endpoint("RDSEndpoint", service=ec2.InterfaceVpcEndpointAwsService.RDS,security_groups=[self._vpc_endpoint_sg])
        self._vpc.add_interface_endpoint("RDSDataEndpoint", service=ec2.InterfaceVpcEndpointAwsService.RDS_DATA,security_groups=[self._vpc_endpoint_sg])
        
        # //********************************************************//
        # //******************* SECURITY GROUP ********************//
        # //*******************************************************//

        # # EFS SG
        # self._eks_efs_sg = ec2.SecurityGroup(self,'EFSSg',
        #     security_group_name=eksname + '-EFS-sg',
        #     vpc=self._vpc,
        #     description='NFS access to EFS from EKS worker nodes',
        # )
        # self._eks_efs_sg.add_ingress_rule(ec2.Peer.ipv4(self._vpc.vpc_cidr_block),ec2.Port.tcp(port=2049))

        # core.Tags.of(self._eks_efs_sg).add('kubernetes.io/cluster/' + eksname,'owned')
        # core.Tags.of(self._eks_efs_sg).add('Name', eksname+'-EFS-sg')