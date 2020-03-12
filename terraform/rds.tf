locals {
  timestamp = formatdate("DD-MMM-YY", timestamp())
}

module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "${var.project}-rds"

  # Uncomment this if you want to build from a snapshot
  # snapshot_identifier = "feb-29-2020-my-aquacsp-snapshot"
  engine                 = "postgres"
  engine_version         = "10.11"
  instance_class         = var.db_instance_type
  allocated_storage      = var.db_storage_size

  name                   = var.project
  username               = var.postgres_username
  password               = data.aws_secretsmanager_secret_version.db_password.secret_string
  port                   = var.postgres_port
  vpc_security_group_ids = [aws_security_group.rds.id]
  maintenance_window     = "Fri:17:00-Fri:17:30"
  backup_window          = "16:00-16:30"
  monitoring_interval    = "30"
  #Role below required if interval above is more than 0
  monitoring_role_arn    = aws_iam_role.rds-enhanced-monitoring.arn
  monitoring_role_name   = "${var.project}-monitoring-role"
  create_monitoring_role = true
  subnet_ids             = module.vpc.database_subnets

  # Aqua CSP requirements:
  # https://docs.aquasec.com/docs/system-requirements
  # Set to false if you don't want upgrade.
  allow_major_version_upgrade = true

  family = "postgres10"
  major_engine_version       = "10"
  final_snapshot_identifier  = "${local.timestamp}-${var.project}"
  deletion_protection        = var.rds_delete_protect
  auto_minor_version_upgrade = true
  backup_retention_period    = "0"
  multi_az                   = var.multple_az
  copy_tags_to_snapshot      = true
  skip_final_snapshot        = var.skip_final_snapshot

  tags = {
    Project   = var.project
    Owner     = var.resource_owner
    Contact   = var.contact
    Terraform = true
    Version   = var.tversion
  }
}