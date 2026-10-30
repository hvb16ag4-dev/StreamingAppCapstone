variable "aws_region" {
  description = "AWS region for the StreamingApp infrastructure."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project prefix used for all AWS resources."
  type        = string
  default     = "streamingapp"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "AWS deployment environment. DEV runs locally and is not provisioned by this Terraform root."
  type        = string

  validation {
    condition     = contains(["uat", "prod"], var.environment)
    error_message = "environment must be uat or prod; DEV is the local Docker Desktop environment."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.37"
}

variable "cluster_public_access_cidrs" {
  description = "IPv4 CIDR ranges allowed to reach the public EKS API endpoint. Use trusted operator/CI egress addresses only."
  type        = list(string)

  validation {
    condition = length(var.cluster_public_access_cidrs) > 0 && !contains(
      var.cluster_public_access_cidrs,
      "0.0.0.0/0"
    )
    error_message = "Provide at least one trusted IPv4 CIDR and do not expose the EKS API to 0.0.0.0/0."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for this environment's VPC. Keep it non-overlapping with connected networks."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of availability zones for the EKS network."
  type        = number
  default     = 3

  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 3
    error_message = "availability_zone_count must be 2 or 3."
  }
}

variable "node_instance_type" {
  description = "Node instance type for the EKS managed node group."
  type        = string
  default     = "t3.medium"
}

variable "desired_capacity" {
  description = "Desired EKS node count."
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum EKS node count."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum EKS node count."
  type        = number
  default     = 3
}

variable "kubernetes_namespace" {
  description = "Namespace used by the app workload and its S3-access service account."
  type        = string
  default     = ""
}

variable "app_service_account_name" {
  description = "Kubernetes service account name allowed to access the media bucket through IRSA."
  type        = string
  default     = ""
}

variable "local_dev_access_enabled" {
  description = "Create a UAT-account role that local DEV can assume for this account's media bucket."
  type        = bool
  default     = false
}

variable "local_dev_access_principal_arns" {
  description = "Exact IAM role ARNs for IAM Identity Center permission sets trusted to assume the local DEV S3 role."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.local_dev_access_principal_arns :
      can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+$", arn))
    ])
    error_message = "Each local_dev_access_principal_arns entry must be an exact IAM role ARN, not an STS assumed-role session ARN."
  }
}

variable "tags" {
  description = "Common tags to apply to cost-traceable AWS resources."
  type        = map(string)
  default = {
    Project   = "streamingapp"
    ManagedBy = "terraform"
  }
}
