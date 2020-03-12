#################################################
# Aqua CSP Project - INPUT REQUIRED
# Variables below assume Tokyo AWS Region
#################################################
region           = "ap-northeast-1"
resource_owner   = "Your Name"
contact          = "you@example.com"
tversion         = "0.12.20"
project          = "aquacsp"
aquacsp_registry = "4.6.20049"

#################################################
# DNS Configuration - INPUT REQUIRED
# You must have already configured a domain name
# and hosted Zone in Route 53 for this to work!!!
#################################################
dns_domain   = "securitynoodles.com"
console_name = "aqua"

###################################################
# Security Group Configuration - INPUT REQUIRED
# Avoid leaving the Aqua CSP open to the world!!!
# Enter a list of IPs
# Main Office: x.x.x.x/32
# Liz's Home: x.x.x.x/32
###################################################
# Please avoid 0.0.0.0/0
aqua_console_access = ["0.0.0.0/0"]

#################################################
# VPC Configuration - OPTIONAL INPUT REQUIRED
# CIDR values are just for reference. You'll
# need to use values that won't overlap with
# other VPC CIDR values.
#################################################
vpc_cidr             = "10.50.0.0/16"
vpc_public_subnets   = ["10.50.1.0/24", "10.50.2.0/24", "10.50.3.0/24"]
vpc_private_subnets  = ["10.50.11.0/24", "10.50.12.0/24", "10.50.13.0/24"]
vpc_database_subnets = ["10.50.111.0/28", "10.50.112.0/28", "10.50.113.0/28"]

# The AZs below are an example for the Tokyo Region.
vpc_azs = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]

#################################################
# Secrets Manager Configuration
# These must be prepared in advance!!!
#################################################
secretsmanager_container_repository = "aqua/container_repository"
secretsmanager_admin_password       = "aqua/admin_password"
secretsmanager_license_token        = "aqua/license_token"
secretsmanager_db_password          = "aqua/db_password"

################################################
# EC2 Configuration - INPUT REQUIRED
# Don't add the .pem of the file name
# Reference sample instance types here:
# https://aws.amazon.com/ec2/instance-types/t3/
################################################
ssh-key_name          = "my-ec2-private-key"
console_instance_type = "t3a.medium"
gateway_instance_type = "t3a.medium"

#################################################
# RDS Configuration - OPTIONAL INPUT REQUIRED
# These settings are mainly for testing. If you
# want this in production, make sure to use
# multi-az and delete protection. Also, go into
# rds.tf and adjust the backup schedule as well
# as snapshot retention, etc.
#################################################
db_instance_type    = "db.t2.large"
postgres_username   = "postgres"
postgres_port       = "5432"
db_storage_size     = 50
multple_az          = false
rds_delete_protect  = false
skip_final_snapshot = true

#################################################
# AQUA Ports
#################################################
aqua_server_console_port = "8080"
aqua_server_gateway_port = "8443"
aqua_enforcer_port       = "3622"

##############################################################################################
# AQUA Containers - OPTIONAL INPUT REQUIRED
# Memory values will depend on your environment
# and choice of EC2 instances!!!
# Note the Task Size section below when sizing:
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html
##############################################################################################
console_memory_size_mb = 2048
console_cpu_units      = 1024
gateway_memory_size_mb = 2048
gateway_cpu_units      = 1024