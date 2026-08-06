variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "aws_account_id" { type = string }
variable "partition" { type = string }
variable "github_oidc_subject_prefix" { type = string }
variable "github_environment" { type = string }
variable "state_bucket_arn" { type = string }
variable "state_kms_key_arn" { type = string }
variable "state_key" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
