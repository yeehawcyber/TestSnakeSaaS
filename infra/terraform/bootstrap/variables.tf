variable "aws_region" {
  type    = string
  default = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "The dev state backend must be bootstrapped in us-east-1."
  }
}

variable "project_name" {
  type    = string
  default = "testsnakesaas"
}

variable "state_bucket_name" {
  description = "Optional globally unique bucket name. The account-scoped default is used when null."
  type        = string
  default     = null
  nullable    = true
}

variable "github_oidc_subject_prefix" {
  description = "Immutable GitHub OIDC repo subject prefix containing owner and repository IDs."
  type        = string
  default     = "repo:yeehawcyber@257407814/TestSnakeSaaS@1323205882"
}

variable "github_environment" {
  description = "Approval-protected GitHub environment trusted by the deploy role."
  type        = string
  default     = "dev"
}
