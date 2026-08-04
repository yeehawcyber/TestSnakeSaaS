locals {
  bucket_name = coalesce(var.state_bucket_name, "${var.project_name}-terraform-state-${data.aws_caller_identity.current.account_id}")
  tags = {
    Application = var.project_name
    Environment = "dev"
    ManagedBy   = "Terraform"
    Purpose     = "Terraform remote state"
    Repository  = "yeehawcyber/TestSnakeSaaS"
  }
}

module "remote_state" {
  source = "../modules/remote-state"

  bucket_name = local.bucket_name
  aws_region  = var.aws_region
  tags        = local.tags
}
