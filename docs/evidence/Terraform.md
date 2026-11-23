# terraform apply
```
Outputs
Apply complete! Resources: 27 added, 0 changed, 0 destroyed.

Outputs:

app_media_access_role_arn = "arn:aws:iam::129373676098:role/streamingapp-uat-eks-media-access-role"
cluster_endpoint = "https://2E002DD4827D6D22DB340B7EFC6A40DA.gr7.ap-south-1.eks.amazonaws.com"
cluster_name = "streamingapp-uat-eks"
load_balancer_controller_role_arn = "arn:aws:iam::129373676098:role/streamingapp-uat-eks-alb-controller-role"
local_dev_media_access_role_arn = ""
local_dev_media_bucket_name = ""
media_bucket_name = "streamingapp-uat-129373676098-ap-south-1"
vpc_id = "vpc-04fbe6ba879594ba9"

```
# terraform state list
```
terraform state list
abhis@Bharathgift MINGW64 ~/Harika/CapstoneProject4_EndToEnd/NOV/StreamingAppCapstone/terraform ((874455b...))
$ terraform state list
data.aws_availability_zones.available
data.aws_caller_identity.current
data.aws_iam_policy_document.app_media_access_assume_role
data.aws_iam_policy_document.load_balancer_controller_assume_role
data.tls_certificate.eks
aws_eks_cluster.main
aws_eks_node_group.main
aws_iam_openid_connect_provider.eks
aws_iam_policy.app_media_access
aws_iam_policy.aws_load_balancer_controller
aws_iam_role.app_media_access
aws_iam_role.cluster
aws_iam_role.load_balancer_controller
aws_iam_role.node_group
aws_iam_role_policy_attachment.app_media_access
aws_iam_role_policy_attachment.cluster_policy
aws_iam_role_policy_attachment.cni_policy
aws_iam_role_policy_attachment.ec2_container_registry_read_only
aws_iam_role_policy_attachment.load_balancer_controller
aws_iam_role_policy_attachment.worker_policy
aws_internet_gateway.main
aws_route_table.public
aws_route_table_association.public[0]
aws_route_table_association.public[1]
aws_s3_bucket.media
aws_s3_bucket_public_access_block.media
aws_s3_bucket_server_side_encryption_configuration.media
aws_s3_bucket_versioning.media
aws_security_group.cluster
aws_subnet.public[0]
aws_subnet.public[1]
aws_vpc.main
```

# terraform destroy
```

Plan: 0 to add, 0 to change, 27 to destroy.

Changes to Outputs:
  - app_media_access_role_arn         = "arn:aws:iam::129373676098:role/streamingapp-uat-eks-media-access-role" -> null
  - cluster_endpoint                  = "https://2E002DD4827D6D22DB340B7EFC6A40DA.gr7.ap-south-1.eks.amazonaws.com" -> null
  - cluster_name                      = "streamingapp-uat-eks" -> null
  - load_balancer_controller_role_arn = "arn:aws:iam::129373676098:role/streamingapp-uat-eks-alb-controller-role" -> null
  - local_dev_media_access_role_arn   = "" -> null
  - local_dev_media_bucket_name       = "" -> null
  - media_bucket_name                 = "streamingapp-uat-129373676098-ap-south-1" -> null
  - vpc_id                            = "vpc-04fbe6ba879594ba9" -> null

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes




```
