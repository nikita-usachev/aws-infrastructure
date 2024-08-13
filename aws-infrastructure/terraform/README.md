# Plan to create infra in AWS

This terraform plan creates resources:
- VPC network
- Route53 zones
- ALB load balancer
- EC2 instances
- ECR registries
- ECS cluster and service
- RDS instances

## Prerequisites

- [awscli](https://github.com/aws/aws-cli) >= 1.27.53
- [terraform](https://www.terraform.io/downloads.html) >= 1.3.4

## AWS credentials

To authenticate terraform plan AWS credentials should be configured for programmatic access
```bash
aws configure
```
If you use multiple credential profiles defined in `~/.aws/credentials`, choose proper one
```bash
export AWS_PROFILE=<profile-name>
```

## Terraform state backend

Terraform configured to keep it's state on s3 bucket. The configuration is defined in the environment's `backend.tf` file (./backend.tf)
```ini
terraform {
  backend "s3" {
    bucket  = "<terraform-states-bucket-name>"
    key     = "<folder-name>"
    region  = "us-east-1"
    encrypt = true
  }
}
```

__NOTE:__
- Bucket that mentioned in `bucket` key should be created first, if not done yet you can do it with
  ```
  aws s3api create-bucket --bucket terraform-states-* --region us-east-1
  ```
- Bucket name must be unique across all existing bucket names and comply with DNS naming conventions
- If you create new environment make sure that you are using unique `key` in the terraform backend configuration
- You can override `backend.tf` configuration with terraform CLI arguments:
  ```
  # using separate bucket for environment
  terraform init -backend-config "bucket=terraform-states-custom"
  ```

## Usage

Resources are logically grouped using Terraform [workspaces](https://www.terraform.io/cli/workspaces) as environments: `prod`, `dev`, etc.

Init terraform backend
```bash
cd terraform
terraform init
```

List environments:
```bash
terraform workspace list
```

Switch or use the environment:
```bash
terraform workspace select <env-name>
```

### Customization

Per environment configuration files with name `<env-name>.tfvars` are used to customize deployments. E.g. [prod.tfvars](./prod.tfvars)

__NOTE:__ That we have to set path to the environment's tfvars files explicitly when run terraform commands, e.g. `terraform plan -var-file <env-name>.tfvars`

#### Create new environment

Create workspace for the new environment:
```bash
terraform workspace new <env-name>
```

Copy environment-specific configuration from `prod.tfvars` or any other value's file to `<env-name>.tfvars` and change env related names and variables in it.

__NOTE:__ That we have to set path to the environment tfvars files explicitly when run terraform commands, e.g. `terraform plan -var-file <env-name>.tfvars`

### Create / Update

To create/update the environment execute terraform plan:
```bash
terraform plan -var-file <env-name>.tfvars
terraform apply -var-file <env-name>.tfvars
```

### Destroy

To remove environment's resources run:
```bash
TF_WARN_OUTPUT_ERRORS=1 terraform destroy -var-file <env-name>.tfvars
```

### Generate ansible inventory (optional)

Further ansible provisioning automation utilizes dynamic inventory from terraform state, to generate inventory run:

```bash
./create_update_ansible_inventory.sh
```

## Spot price (optional)

You can check price in case spot instances used:
```bash
echo "$(aws ec2 describe-spot-price-history --region us-east-1 --start-time=$(date +%s) --product-descriptions="Linux/UNIX" --query 'max(SpotPriceHistory[*].SpotPrice)' --instance-types t3.medium|tr -d \")"
```
