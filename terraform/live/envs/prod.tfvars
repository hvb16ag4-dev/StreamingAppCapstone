aws_region                  = "ap-south-1"
project_name                = "streamingapp"
cluster_version             = "1.37"
cluster_public_access_cidrs = ["10.10.0.0/24"]
node_instance_type          = "t3.medium"
desired_capacity            = 2
min_capacity                = 1
max_capacity                = 3

tags = {
  Project     = "streamingapp"
  Environment = "prod"
  ManagedBy   = "terraform"
}
