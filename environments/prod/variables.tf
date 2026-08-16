# =============================================================================
# Production Environment — Variables
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "cluster_name_prefix" {
  description = "Prefix for cluster names"
  type        = string
  default     = "devsecops"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.2.0.0/16"
}

variable "public_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.2.1.0/24", "10.2.2.0/24"]
}

variable "private_cidrs" {
  description = "Private subnet CIDRs (EKS)"
  type        = list(string)
  default     = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
}

variable "common_tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    Project   = "devsecops-chaos-lab"
    ManagedBy = "terraform"
  }
}
