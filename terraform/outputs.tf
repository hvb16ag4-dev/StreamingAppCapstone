output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS control-plane endpoint."
  value       = aws_eks_cluster.main.endpoint
}

output "vpc_id" {
  description = "VPC ID for the EKS environment."
  value       = aws_vpc.main.id
}

output "ecr_repositories" {
  description = "Map of ECR repository names for app images."
  value = {
    for key, repo in aws_ecr_repository.services : key => repo.repository_url
  }
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller."
  value       = aws_iam_role.load_balancer_controller.arn
}

output "media_bucket_name" {
  description = "Private S3 bucket for this environment's video and thumbnail objects."
  value       = aws_s3_bucket.media.bucket
}

output "app_media_access_role_arn" {
  description = "IRSA role ARN for the app service account's least-privilege S3 access."
  value       = aws_iam_role.app_media_access.arn
}

output "local_dev_media_access_role_arn" {
  description = "Optional short-lived role ARN for local DEV to access its isolated UAT-account media bucket."
  value       = var.local_dev_access_enabled ? aws_iam_role.local_dev_media_access[0].arn : ""
}

output "local_dev_media_bucket_name" {
  description = "Optional separate media bucket for local DEV testing in the UAT account."
  value       = var.local_dev_access_enabled ? aws_s3_bucket.local_dev_media[0].bucket : ""
}
