# --------------------------------------------------
# REDE: VPC com subnets públicas e privadas (substitui a rede do Minikube)
#
# Layout (com vpc_cidr = 10.0.0.0/16 e az_count = 2):
#   privadas: 10.0.0.0/20, 10.0.16.0/20   -> nós do EKS, RDS, NLB interno, VPC Link
#   públicas: 10.0.48.0/24, 10.0.49.0/24  -> NAT Gateway
# --------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)]

  # Um único NAT Gateway (mais barato para o TCC)
  enable_nat_gateway = true
  single_nat_gateway = true

  # Tags que o EKS usa para descobrir onde criar Load Balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
