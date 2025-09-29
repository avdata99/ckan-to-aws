import aws_cdk as cdk
from aws_cdk import (
    aws_ecs as ecs,
    aws_ec2 as ec2,
    aws_elasticloadbalancingv2 as elbv2,
    aws_logs as logs,
    aws_rds as rds,
    aws_secretsmanager as secretsmanager
)
from constructs import Construct


class CkanStack(cdk.Stack):
    def __init__(self, scope: Construct, construct_id: str, vpc: ec2.Vpc,
                 cluster: ecs.Cluster, database: rds.DatabaseInstance,
                 solr_service: ecs.FargateService, redis_service: ecs.FargateService,
                 env_name: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.env_name = env_name
        self.vpc = vpc
        self.cluster = cluster
        self.database = database
        self.solr_service = solr_service
        self.redis_service = redis_service

        # Get security groups
        self.alb_security_group = ec2.SecurityGroup.from_lookup_by_id(
            self, "ImportedAlbSecurityGroup",
            security_group_id=cdk.Fn.import_value(f"ckan-{env_name}-network:AlbSecurityGroupId")
        ) if env_name == "prod" else None

        self.ecs_security_group = ec2.SecurityGroup.from_lookup_by_id(
            self, "ImportedEcsSecurityGroup",
            security_group_id=cdk.Fn.import_value(f"ckan-{env_name}-network:EcsSecurityGroupId")
        ) if env_name == "prod" else None

        # Create ALB
        self._create_load_balancer()

        # Create CKAN service
        self._create_ckan_service()

        # Setup ALB target group and listener
        self._setup_alb_routing()

        # Outputs
        cdk.CfnOutput(
            self, "LoadBalancerDNS",
            value=self.alb.load_balancer_dns_name,
            description="DNS name of the Application Load Balancer"
        )

        cdk.CfnOutput(
            self, "CkanUrl",
            value=f"http://{self.alb.load_balancer_dns_name}",
            description="CKAN application URL"
        )

    def _create_load_balancer(self):
        # Application Load Balancer
        self.alb = elbv2.ApplicationLoadBalancer(
            self, "CkanLoadBalancer",
            vpc=self.vpc,
            internet_facing=True,
            load_balancer_name=f"ckan-{self.env_name}-alb",
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PUBLIC
            ),
            security_group=self.alb_security_group
        )

    def _create_ckan_service(self):
        # CKAN task definition
        self.ckan_task_def = ecs.FargateTaskDefinition(
            self, "CkanTaskDefinition",
            family=f"ckan-{self.env_name}-app",
            memory_limit_mib=2048 if self.env_name == "dev" else 4096,
            cpu=1024 if self.env_name == "dev" else 2048
        )

        # Database connection string from secrets
        db_secret = secretsmanager.Secret.from_secret_arn(
            self, "DatabaseSecret",
            secret_arn=self.database.secret.secret_arn
        )

        # CKAN container
        self.ckan_container = self.ckan_task_def.add_container(
            "CkanContainer",
            image=ecs.ContainerImage.from_registry("ckan/ckan:2.10"),
            memory_limit_mib=2048 if self.env_name == "dev" else 4096,
            environment={
                "CKAN_SQLALCHEMY_URL": f"postgresql://ckan@{self.database.instance_endpoint.hostname}:5432/ckan",
                "CKAN_SOLR_URL": f"http://{self.solr_service.service_name}.{self.cluster.cluster_name}.local:8983/solr/ckan",
                "CKAN_REDIS_URL": f"redis://{self.redis_service.service_name}.{self.cluster.cluster_name}.local:6379/0",
                "CKAN_SITE_URL": f"http://ckan-{self.env_name}-alb.{self.region}.elb.amazonaws.com",
                "CKAN_MAX_UPLOAD_SIZE_MB": "10" if self.env_name == "dev" else "100"
            },
            secrets={
                "CKAN_DB_PASSWORD": ecs.Secret.from_secrets_manager(db_secret, "password")
            },
            logging=ecs.LogDrivers.aws_logs(
                stream_prefix="ckan",
                log_group=logs.LogGroup(
                    self, "CkanLogGroup",
                    log_group_name=f"/ecs/ckan-{self.env_name}-app",
                    retention=logs.RetentionDays.ONE_WEEK if self.env_name == "dev" else logs.RetentionDays.ONE_MONTH
                )
            ),
            health_check=ecs.HealthCheck(
                command=["CMD-SHELL", "curl -f http://localhost:5000/api/3/action/status_show || exit 1"],
                interval=cdk.Duration.seconds(30),
                timeout=cdk.Duration.seconds(5),
                retries=3,
                start_period=cdk.Duration.seconds(60)
            )
        )

        self.ckan_container.add_port_mappings(
            ecs.PortMapping(container_port=5000, protocol=ecs.Protocol.TCP)
        )

        # CKAN service
        self.ckan_service = ecs.FargateService(
            self, "CkanService",
            cluster=self.cluster,
            task_definition=self.ckan_task_def,
            service_name=f"ckan-{self.env_name}-app",
            desired_count=1 if self.env_name == "dev" else 2,
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS
            ),
            security_groups=[self.ecs_security_group] if self.ecs_security_group else [],
            enable_logging=True,
            health_check_grace_period=cdk.Duration.seconds(300)
        )

    def _setup_alb_routing(self):
        # Target group for CKAN
        self.target_group = elbv2.ApplicationTargetGroup(
            self, "CkanTargetGroup",
            vpc=self.vpc,
            port=5000,
            protocol=elbv2.ApplicationProtocol.HTTP,
            target_type=elbv2.TargetType.IP,
            health_check=elbv2.HealthCheck(
                enabled=True,
                healthy_http_codes="200",
                interval=cdk.Duration.seconds(30),
                path="/api/3/action/status_show",
                protocol=elbv2.Protocol.HTTP,
                timeout=cdk.Duration.seconds(5),
                healthy_threshold_count=2,
                unhealthy_threshold_count=5
            )
        )

        # Add ECS service to target group
        self.target_group.add_target(
            elbv2.EcsServiceTarget(
                service=self.ckan_service,
                container_name="CkanContainer",
                container_port=5000
            )
        )

        # ALB listener
        self.listener = self.alb.add_listener(
            "CkanListener",
            port=80,
            protocol=elbv2.ApplicationProtocol.HTTP,
            default_target_groups=[self.target_group]
        )
