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
