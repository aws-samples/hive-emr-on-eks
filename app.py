#!/usr/bin/env python3
from aws_cdk.core import (App,Tags,CfnOutput)
from source.lib.emr_on_ec2_stack import EMREC2Stack
from source.lib.spark_on_eks_stack import SparkOnEksStack


app = App()
proj_name = app.node.try_get_context('project_name')
emr_release_v=app.node.try_get_context('emr_version')

# main stacks
eks_stack = SparkOnEksStack(app, 'HiveEMRonEKS', proj_name)
# Configure RDS as hive metastore DB via EMR on EC2
hive_emr_ec2_stack = EMREC2Stack(eks_stack, 'EMRonEC2', emr_release_v, eks_stack.eks_cluster,eks_stack.code_bucket,eks_stack.rds_secret)


Tags.of(eks_stack).add('project', proj_name)
Tags.of(hive_emr_ec2_stack).add('project', proj_name)

# Deployment Output
CfnOutput(eks_stack,'CODE_BUCKET', value=eks_stack.code_bucket)
CfnOutput(eks_stack, "VirtualClusterId",value=eks_stack.EMRVC)
CfnOutput(eks_stack, "EMRExecRoleARN", value=eks_stack.EMRExecRole)
CfnOutput(eks_stack, "HiveSecretName", value=eks_stack.rds_secret.secret_name)

app.synth()