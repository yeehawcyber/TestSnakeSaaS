variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "aws_account_id" { type = string }
variable "partition" { type = string }
variable "github_repository" { type = string }
variable "github_oidc_subject_prefix" { type = string }
variable "github_environment" { type = string }
variable "create_oidc_provider" { type = bool }
variable "existing_oidc_provider_arn" {
  type     = string
  default  = null
  nullable = true
}
variable "state_bucket_arn" { type = string }
variable "state_kms_key_arn" { type = string }
variable "state_key" { type = string }
variable "ecr_repository_arn" { type = string }
variable "ecs_execution_role_arn" { type = string }
variable "ecs_task_role_arn" { type = string }
variable "route53_zone_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
