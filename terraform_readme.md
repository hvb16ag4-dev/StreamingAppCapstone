### On AWS (dev)

```bash
cd terraform/live
# set your state bucket in backend/dev.hcl first
terraform init -backend-config=backend/dev.hcl
terraform plan  -var-file=envs/dev.tfvars -out=dev.tfplan
terraform apply dev.tfplan

terraform destroy -var-file=envs/dev.tfvars   # when done
```