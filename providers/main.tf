# =============================================================================
# Providers — Shared AWS modules (EKS, Networking, IRSA)
# Reference: enterprise-terraform-aws/modules/
# ============================================================
# This directory contains references to shared modules used across the portfolio.
# Deploy from environments/<env>/ with terraform init/up.
# ============================================================

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # S3 backend — uncomment and configure per environment:
  # backend "s3" {
  #   bucket         = ""
  #   key            = ""
  #   region         = ""
  #   encrypt        = true
  #   force_destroy  = false
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ---------------------------------------------------------------------------
# Networking - VPC, Subnets, NAT, Security Groups
# ---------------------------------------------------------------------------
module "networking" {
  source = "../../enterprise-terraform-aws/modules/networking"

  aws_region    = var.aws_region
  environment   = var.environment
  vpc_cidr      = var.vpc_cidr
  public_cidrs  = var.public_cidrs
  private_cidrs = var.private_cidrs
  db_cidrs      = []

  common_tags = var.common_tags
}

# ---------------------------------------------------------------------------
# EKS - Managed Kubernetes Cluster
# Single node group optimized for development and chaos experiments
# ---------------------------------------------------------------------------
module "eks" {
  source = "../../enterprise-terraform-aws/modules/eks"

  aws_region              = var.aws_region
  environment             = var.environment
  cluster_name            = "${var.cluster_name_prefix}-secops-lab"
  cluster_version         = "1.31"
  vpc_id                  = module.networking.vpc_id
  subnet_ids              = module.networking.private_subnet_ids
  eks_cluster_sg_id       = module.networking.eks_cluster_sg_id

  node_group_instance_type = var.eks_node_instance_type
  node_group_desired_size  = var.eks_node_desired_size
  node_group_min_size      = var.eks_node_min_size
  node_group_max_size      = var.eks_node_max_size

  common_tags = var.common_tags
}

# ---------------------------------------------------------------------------
# IRSA - IAM Roles for Service Accounts
# Enables LitmusChaos service accounts to interact with EKS
# ---------------------------------------------------------------------------
module "eks-irsa" {
  source = "../../enterprise-terraform-aws/modules/eks-irsa"

  cluster_id              = module.eks.cluster_id
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  environment             = var.environment

  # Allow LitmusChaos to manage pods and namespaces for chaos experiments
  additional_policies = {
    litmus-admin = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["*"]
          Resource = "*"
        }
      ]
    })
  }

  common_tags = var.common_tags

  depends_on = [module.eks]
}
