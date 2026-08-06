variable "aws_region" {
  type    = string
  default = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "Bootstrap access is intentionally limited to us-east-1."
  }
}

variable "aws_account_id" {
  type    = string
  default = "620649695133"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "github_oidc_subject_prefix" {
  type    = string
  default = "repo:yeehawcyber@257407814/TestSnakeSaaS@1323205882"
}

variable "github_environment" {
  type    = string
  default = "infra-bootstrap"
}

variable "state_bucket_name" {
  type    = string
  default = "testsnakesaas-terraform-state-620649695133"
}

variable "state_kms_key_arn" {
  type    = string
  default = "arn:aws:kms:us-east-1:620649695133:key/c0a70a0b-ece6-454c-986c-7c0ed9fa659e"
}
