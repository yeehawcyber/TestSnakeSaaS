variable "aws_region" {
  description = "AWS Region for the dev workload."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "This configuration is intentionally limited to dev in us-east-1."
  }
}

variable "project_name" {
  description = "Stable project identifier used for names and tags."
  type        = string
  default     = "testsnakesaas"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "Only the dev environment is permitted by this Terraform root."
  }
}

variable "image_tag" {
  description = "Immutable 40-character lowercase deployment image identifier."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{40}$", var.image_tag))
    error_message = "image_tag must be a 40-character lowercase hexadecimal identifier."
  }
}

variable "application_callback_url" {
  description = "Registered Cognito callback/logout URL. Use localhost only for the first apply, then replace it with the API endpoint output."
  type        = string
  default     = "http://localhost:3000"

  validation {
    condition     = var.application_callback_url == "http://localhost:3000" || can(regex("^https://[a-z0-9]+\\.execute-api\\.us-east-1\\.amazonaws\\.com/?$", var.application_callback_url))
    error_message = "Use http://localhost:3000 for bootstrap or the generated us-east-1 execute-api HTTPS endpoint."
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

variable "budget_alert_email" {
  description = "Optional email for 80 percent actual and 100 percent forecast AWS Budget alerts."
  type        = string
  sensitive   = true
  default     = null
  nullable    = true

  validation {
    condition     = var.budget_alert_email == null || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget_alert_email))
    error_message = "budget_alert_email must be null or a valid email address."
  }
}

variable "bedrock_inference_profile_id" {
  type    = string
  default = "us.amazon.nova-lite-v1:0"
}

variable "bedrock_foundation_model_id" {
  type    = string
  default = "amazon.nova-lite-v1:0"
}

variable "github_repository" {
  type    = string
  default = "yeehawcyber/TestSnakeSaaS"
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}
