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

module "github_actions" {
  source = "../modules/github-actions-serverless"

  name_prefix                = "${var.project_name}-dev"
  aws_region                 = var.aws_region
  aws_account_id             = data.aws_caller_identity.current.account_id
  partition                  = data.aws_partition.current.partition
  github_oidc_subject_prefix = var.github_oidc_subject_prefix
  github_environment         = var.github_environment
  state_bucket_arn           = module.remote_state.bucket_arn
  state_kms_key_arn          = module.remote_state.kms_key_arn
  state_key                  = "testsnakesaas/dev/terraform.tfstate"
  tags                       = merge(local.tags, { Purpose = "GitHub Actions OIDC" })
}
