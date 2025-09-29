import aws_cdk as cdk
from aws_cdk import aws_rds as rds, aws_ec2 as ec2
from constructs import Construct

class DatabaseStack(cdk.Stack):
    def __init__(self, scope: Construct, construct_id: str, vpc: ec2.Vpc, env_name: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        self.env_name = env_name
        self.vpc = vpc

        # Get security group from network stack
        self.db_security_group = ec2.SecurityGroup.from_lookup_by_id(
            self, "ImportedDbSecurityGroup",
            security_group_id=cdk.Fn.import_value(f"ckan-{env_name}-network:RdsSecurityGroupId")
        ) if env_name == "prod" else None

        # Database subnet group
        self.db_subnet_group = rds.SubnetGroup(
            self, "CkanDbSubnetGroup",
            description=f"Subnet group for CKAN database ({env_name})",
            vpc=self.vpc,
            vpc_subnets=ec2.SubnetSelection(
                subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS
            )
        )

        # Database instance configuration based on environment
        instance_class = ec2.InstanceType.of(
            ec2.InstanceClass.BURSTABLE3,
            ec2.InstanceSize.MICRO if env_name == "dev" else ec2.InstanceSize.SMALL
        )

        # Database credentials
        self.db_credentials = rds.Credentials.from_generated_secret(
            username="ckan",
            secret_name=f"ckan-{env_name}-db-credentials"
        )

        # RDS PostgreSQL instance
        self.database = rds.DatabaseInstance(
            self, "CkanDatabase",
            engine=rds.DatabaseInstanceEngine.postgres(
                version=rds.PostgresEngineVersion.VER_14
            ),
            instance_type=instance_class,
            credentials=self.db_credentials,
            database_name="ckan",
            vpc=self.vpc,
            subnet_group=self.db_subnet_group,
            security_groups=[self.db_security_group] if self.db_security_group else [],
            allocated_storage=20 if env_name == "dev" else 100,
            max_allocated_storage=100 if env_name == "dev" else 500,
            storage_encrypted=True,
            backup_retention=cdk.Duration.days(1 if env_name == "dev" else 7),
            deletion_protection=False if env_name == "dev" else True,
            delete_automated_backups=True if env_name == "dev" else False,
            multi_az=False if env_name == "dev" else True,
            auto_minor_version_upgrade=True,
            parameter_group=rds.ParameterGroup.from_parameter_group_name(
                self, "DefaultParameterGroup",
                parameter_group_name="default.postgres14"
            )
        )

        # Outputs
        cdk.CfnOutput(
            self, "DatabaseEndpoint",
            value=self.database.instance_endpoint.hostname,
            export_name=f"ckan-{env_name}-db-endpoint"
        )

        cdk.CfnOutput(
            self, "DatabasePort",
            value=str(self.database.instance_endpoint.port),
            export_name=f"ckan-{env_name}-db-port"
        )

        cdk.CfnOutput(
            self, "DatabaseName",
            value="ckan",
            export_name=f"ckan-{env_name}-db-name"
        )

        cdk.CfnOutput(
            self, "DatabaseSecretArn",
            value=self.database.secret.secret_arn,
            export_name=f"ckan-{env_name}-db-secret-arn"
        )
