import aws_cdk as cdk
from aws_cdk import aws_ecs as ecs, aws_ec2 as ec2, aws_logs as logs
from constructs import Construct


class ServicesStack(cdk.Stack):
    def __init__(self, scope: Construct, construct_id: str, vpc: ec2.Vpc, env_name: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.env_name = env_name
        self.vpc = vpc

        # ECS Cluster
        self.cluster = ecs.Cluster(
            self, "CkanCluster",
            cluster_name=f"ckan-{env_name}-cluster",
            vpc=self.vpc,
            container_insights=True if env_name == "prod" else False
        )

        # Get security group for ECS services
        self.ecs_security_group = ec2.SecurityGroup.from_lookup_by_id(
            self, "ImportedEcsSecurityGroup",
            security_group_id=cdk.Fn.import_value(f"ckan-{env_name}-network:EcsSecurityGroupId")
        ) if env_name == "prod" else None

        # Task execution role
        self.task_execution_role = ecs.TaskDefinition.from_task_definition_arn(
            self, "DefaultTaskRole",
            task_definition_arn="arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
        ).task_role if False else None

        # Solr service
        self._create_solr_service()

        # Redis service
        self._create_redis_service()

        # Outputs
        cdk.CfnOutput(
            self, "ClusterName",
            value=self.cluster.cluster_name,
            export_name=f"ckan-{env_name}-cluster-name"
        )

    def _create_solr_service(self):
        # Solr task definition
        self.solr_task_def = ecs.FargateTaskDefinition(
            self, "SolrTaskDefinition",
            family=f"ckan-{self.env_name}-solr",
            memory_limit_mib=1024 if self.env_name == "dev" else 2048,
            cpu=512 if self.env_name == "dev" else 1024
        )

        # Solr container with CKAN schema
        self.solr_container = self.solr_task_def.add_container(
            "SolrContainer",
            image=ecs.ContainerImage.from_asset("./docker/solr"),
            memory_limit_mib=1024 if self.env_name == "dev" else 2048,
            environment={
                "SOLR_HEAP": "512m" if self.env_name == "dev" else "1g"
            },
            logging=ecs.LogDrivers.aws_logs(
                stream_prefix="solr",
                log_group=logs.LogGroup(
                    self, "SolrLogGroup",
                    log_group_name=f"/ecs/ckan-{self.env_name}-solr",
                    retention=logs.RetentionDays.ONE_WEEK if self.env_name == "dev" else logs.RetentionDays.ONE_MONTH
                )
            ),
            health_check=ecs.HealthCheck(
                command=[
                    "CMD-SHELL",
                    "wget -qO- http://localhost:8983/solr/ckan/admin/ping | grep '\"status\":\"OK\"' || exit 1"
                ],
                interval=cdk.Duration.seconds(30),
                timeout=cdk.Duration.seconds(10),
                retries=3,
                start_period=cdk.Duration.seconds(60)
            )
        )

        self.solr_container.add_port_mappings(
            ecs.PortMapping(container_port=8983, protocol=ecs.Protocol.TCP)
        )

        # Solr service
        self.solr_service = ecs.FargateService(
            self, "SolrService",
            cluster=self.cluster,
            task_definition=self.solr_task_def,
            service_name=f"ckan-{self.env_name}-solr",
            desired_count=1,
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS
            ),
            security_groups=[self.ecs_security_group] if self.ecs_security_group else [],
            enable_logging=True,
            health_check_grace_period=cdk.Duration.seconds(120)
        )

    def _create_redis_service(self):
        # Redis/Valkey task definition
        self.redis_task_def = ecs.FargateTaskDefinition(
            self, "RedisTaskDefinition",
            family=f"ckan-{self.env_name}-redis",
            memory_limit_mib=512 if self.env_name == "dev" else 1024,
            cpu=256 if self.env_name == "dev" else 512
        )

        # Redis/Valkey container - simplified configuration
        self.redis_container = self.redis_task_def.add_container(
            "RedisContainer",
            image=ecs.ContainerImage.from_asset("./docker/redis"),
            memory_limit_mib=512 if self.env_name == "dev" else 1024,
            logging=ecs.LogDrivers.aws_logs(
                stream_prefix="redis",
                log_group=logs.LogGroup(
                    self, "RedisLogGroup",
                    log_group_name=f"/ecs/ckan-{self.env_name}-redis",
                    retention=logs.RetentionDays.ONE_WEEK if self.env_name == "dev" else logs.RetentionDays.ONE_MONTH
                )
            ),
            health_check=ecs.HealthCheck(
                command=["CMD-SHELL", "valkey-cli ping | grep PONG || exit 1"],
                interval=cdk.Duration.seconds(30),
                timeout=cdk.Duration.seconds(5),
                retries=3,
                start_period=cdk.Duration.seconds(10)
            )
        )

        self.redis_container.add_port_mappings(
            ecs.PortMapping(container_port=6379, protocol=ecs.Protocol.TCP)
        )

        # Redis service
        self.redis_service = ecs.FargateService(
            self, "RedisService",
            cluster=self.cluster,
            task_definition=self.redis_task_def,
            service_name=f"ckan-{self.env_name}-redis",
            desired_count=1,
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS
            ),
            security_groups=[self.ecs_security_group] if self.ecs_security_group else [],
            enable_logging=True,
            health_check_grace_period=cdk.Duration.seconds(60)
        )

        # Output Redis service discovery info
        cdk.CfnOutput(
            self, "RedisServiceName",
            value=self.redis_service.service_name,
            export_name=f"ckan-{self.env_name}-redis-service-name"
        )
