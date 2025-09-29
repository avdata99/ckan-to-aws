import aws_cdk as cdk
from aws_cdk import aws_ec2 as ec2
from constructs import Construct

class NetworkStack(cdk.Stack):
    def __init__(self, scope: Construct, construct_id: str, env_name: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.env_name = env_name

        # Create VPC with public and private subnets
        self.vpc = ec2.Vpc(
            self, "CkanVpc",
            vpc_name=f"ckan-{env_name}-vpc",
            ip_addresses=ec2.IpAddresses.cidr("10.0.0.0/16"),
            max_azs=2,
            subnet_configuration=[
                ec2.SubnetConfiguration(
                    name="PublicSubnet",
                    subnet_type=ec2.SubnetType.PUBLIC,
                    cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="PrivateSubnet",
                    subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                    cidr_mask=24
                )
            ],
            enable_dns_hostnames=True,
            enable_dns_support=True
        )

        # Security group for ALB (public access)
        self.alb_security_group = ec2.SecurityGroup(
            self, "AlbSecurityGroup",
            vpc=self.vpc,
            description="Security group for Application Load Balancer",
            allow_all_outbound=True
        )

        self.alb_security_group.add_ingress_rule(
            peer=ec2.Peer.any_ipv4(),
            connection=ec2.Port.tcp(80),
            description="Allow HTTP traffic"
        )

        self.alb_security_group.add_ingress_rule(
            peer=ec2.Peer.any_ipv4(),
            connection=ec2.Port.tcp(443),
            description="Allow HTTPS traffic"
        )

        # Security group for ECS services
        self.ecs_security_group = ec2.SecurityGroup(
            self, "EcsSecurityGroup",
            vpc=self.vpc,
            description="Security group for ECS services",
            allow_all_outbound=True
        )

        # Security group for RDS
        self.rds_security_group = ec2.SecurityGroup(
            self, "RdsSecurityGroup",
            vpc=self.vpc,
            description="Security group for RDS PostgreSQL",
            allow_all_outbound=False
        )

        # Allow ECS services to connect to RDS
        self.rds_security_group.add_ingress_rule(
            peer=self.ecs_security_group,
            connection=ec2.Port.tcp(5432),
            description="Allow PostgreSQL access from ECS"
        )

        # Allow ALB to connect to ECS services
        self.ecs_security_group.add_ingress_rule(
            peer=self.alb_security_group,
            connection=ec2.Port.tcp(5000),
            description="Allow ALB to reach CKAN app"
        )

        # Allow ECS services to communicate with each other
        self.ecs_security_group.add_ingress_rule(
            peer=self.ecs_security_group,
            connection=ec2.Port.all_traffic(),
            description="Allow inter-service communication"
        )

        # Outputs
        cdk.CfnOutput(self, "VpcId", value=self.vpc.vpc_id)
        cdk.CfnOutput(self, "VpcCidr", value=self.vpc.vpc_cidr_block)
