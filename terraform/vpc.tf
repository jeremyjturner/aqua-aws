module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.project}-vpc"
  cidr = var.vpc_cidr

  azs = var.vpc_azs

  # Aqua Server goes here
  public_subnets = var.vpc_public_subnets
  # Aqua Gateway goes here
  private_subnets = var.vpc_private_subnets
  # Aqua Postgres DB goes here
  database_subnets = var.vpc_database_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  tags = {
    Owner     = var.resource_owner
    Contact   = var.contact
    Terraform = true
    Version   = var.tversion
  }
}