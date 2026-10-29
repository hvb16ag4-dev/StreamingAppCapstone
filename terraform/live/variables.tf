variable "aws_region" {
  description = "AWS region for the StreamingApp infrastructure."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project prefix used for all AWS resources."
  type        = string
  default     = "streamingapp"
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

variable "tags" {
  description = "Common tags to apply to cost-traceable AWS resources."
  type        = map(string)
  default = {
    Project     = "streamingapp"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
