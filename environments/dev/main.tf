# =============================================================================
# Dev Environment — Terraform Configuration
# Cost-optimized EKS cluster for security scanning and chaos experiments
# ============================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

locals {
  environment = "dev"
  common_tags = merge(var.common_tags, { Environment = local.environment })
}

# ---------------------------------------------------------------------------
# Reuse providers layer (EKS cluster + networking)
# ---------------------------------------------------------------------------
module "providers" {
  source = "../../providers"

  aws_region           = var.aws_region
  environment          = local.environment
  cluster_name_prefix  = var.cluster_name_prefix
  vpc_cidr             = var.vpc_cidr
  public_cidrs         = var.public_cidrs
  private_cidrs        = var.private_cidrs
  common_tags          = local.common_tags

  eks_node_instance_type = "t3.small"
  eks_node_desired_size  = 1
  eks_node_min_size      = 1
  eks_node_max_size      = 2
}

# ---------------------------------------------------------------------------
# Output: EKS kubeconfig alias for kubectl
# ---------------------------------------------------------------------------
output "cluster_name" {
  description = "Dev EKS cluster name"
  value       = module.providers.eks_cluster_name
}

output "cluster_endpoint" {
  description = "Dev EKS cluster endpoint"
  value       = module.providers.eks_cluster_endpoint
}
