#!/usr/bin/env python3
import aws_cdk as cdk
from ckan_aws.network_stack import NetworkStack
from ckan_aws.database_stack import DatabaseStack
from ckan_aws.services_stack import ServicesStack
from ckan_aws.ckan_stack import CkanStack

app = cdk.App()

# Get environment from context
env_name = app.node.try_get_context("environment") or "dev"
env = cdk.Environment(
    account=app.node.try_get_context("account"),
    region=app.node.try_get_context("region") or "us-east-1"
)

# Stack naming convention
stack_prefix = f"ckan-{env_name}"

# Network stack (VPC, subnets, security groups)
network_stack = NetworkStack(
    app, f"{stack_prefix}-network",
    env_name=env_name,
    env=env
)

# Database stack (RDS PostgreSQL)
database_stack = DatabaseStack(
    app, f"{stack_prefix}-database",
    vpc=network_stack.vpc,
    env_name=env_name,
    env=env
)

# Services stack (ECS cluster, Solr, Redis)
services_stack = ServicesStack(
    app, f"{stack_prefix}-services",
    vpc=network_stack.vpc,
    env_name=env_name,
    env=env
)

# CKAN stack (CKAN app with ALB)
ckan_stack = CkanStack(
    app, f"{stack_prefix}-ckan",
    vpc=network_stack.vpc,
    cluster=services_stack.cluster,
    database=database_stack.database,
    solr_service=services_stack.solr_service,
    redis_service=services_stack.redis_service,
    env_name=env_name,
    env=env
)

app.synth()
