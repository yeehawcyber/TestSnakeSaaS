variable "aws_region" {
  description = "AWS Region for the dev workload."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "This configuration is intentionally limited to the dev environment in us-east-1."
  }
}

variable "project_name" {
  description = "Stable project identifier used for names and tags."
  type        = string
  default     = "testsnakesaas"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.project_name))
    error_message = "project_name must be 3-24 lowercase alphanumeric or hyphen characters and start with a letter."
  }
}

variable "environment" {
  description = "Deployment environment. Production is intentionally unsupported by this root module."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "Only the dev environment is permitted by this Terraform root."
  }
}

variable "domain_name" {
  description = "Fully qualified public hostname for the application, for example dev.snake.example.com."
  type        = string

  validation {
    condition     = length(var.domain_name) >= 4 && length(var.domain_name) <= 253 && can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "domain_name must be a lowercase fully qualified DNS hostname."
  }
}

variable "route53_zone_id" {
  description = "Existing public Route 53 hosted zone ID authoritative for domain_name."
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]{10,32}$", var.route53_zone_id))
    error_message = "route53_zone_id must be a Route 53 hosted zone ID beginning with Z."
  }
}

variable "cognito_domain_prefix" {
  description = "Globally unique prefix for the Cognito hosted UI domain."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$", var.cognito_domain_prefix))
    error_message = "cognito_domain_prefix must be 1-63 lowercase letters, numbers, or internal hyphens."
  }
}

variable "image_tag" {
  description = "Immutable full Git commit SHA used as the ECR image tag."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.image_tag))
    error_message = "image_tag must be a 40-character lowercase Git commit SHA."
  }
}

variable "vpc_cidr" {
  description = "CIDR allocated to the dev VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "allowed_ingress_cidrs" {
  description = "IPv4 CIDRs allowed to reach the public ALB on ports 80 and 443."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "desired_count" {
  description = "Steady-state ECS task count."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 4
    error_message = "desired_count must be between 1 and 4 for dev."
  }
}

variable "state_bucket_arn" {
  description = "ARN of the S3 bucket created by bootstrap; used to scope GitHub Actions state access."
  type        = string
}

variable "state_kms_key_arn" {
  description = "ARN of the KMS key created by bootstrap; used to scope GitHub Actions state encryption."
  type        = string
}

variable "state_key" {
  description = "S3 object key used by this root module's backend."
  type        = string
  default     = "testsnakesaas/dev/terraform.tfstate"
}

variable "github_repository" {
  description = "GitHub owner/repository permitted to obtain OIDC credentials."
  type        = string
  default     = "yeehawcyber/TestSnakeSaaS"
}

variable "github_oidc_subject_prefix" {
  description = "Immutable GitHub OIDC repo subject prefix containing owner and repository IDs."
  type        = string
  default     = "repo:yeehawcyber@257407814/TestSnakeSaaS@1323205882"
}

variable "create_github_oidc_provider" {
  description = "Create the account-level GitHub OIDC provider. Set false only when importing/using an existing provider."
  type        = bool
  default     = true
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN when create_github_oidc_provider is false."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.create_github_oidc_provider || (var.existing_github_oidc_provider_arn != null && can(regex("^arn:[^:]+:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.existing_github_oidc_provider_arn)))
    error_message = "Provide a valid existing GitHub OIDC provider ARN when creation is disabled."
  }
}

variable "bedrock_inference_profile_id" {
  description = "System-defined Bedrock inference profile used by the application."
  type        = string
  default     = "us.amazon.nova-lite-v1:0"

  validation {
    condition     = var.bedrock_inference_profile_id == "us.amazon.nova-lite-v1:0"
    error_message = "The dev task role is intentionally restricted to us.amazon.nova-lite-v1:0."
  }
}

variable "bedrock_foundation_model_id" {
  description = "Foundation model routed by the Nova Lite inference profile."
  type        = string
  default     = "amazon.nova-lite-v1:0"

  validation {
    condition     = var.bedrock_foundation_model_id == "amazon.nova-lite-v1:0"
    error_message = "The dev task role is intentionally restricted to amazon.nova-lite-v1:0."
  }
}

variable "additional_tags" {
  description = "Additional non-sensitive tags to apply to all supported resources."
  type        = map(string)
  default     = {}
}
