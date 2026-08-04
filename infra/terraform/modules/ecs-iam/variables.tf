variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "aws_account_id" { type = string }
variable "partition" { type = string }
variable "ecr_repository_arn" { type = string }
variable "log_group_arn" { type = string }
variable "bedrock_inference_profile_id" { type = string }
variable "bedrock_foundation_model_id" { type = string }
variable "bedrock_model_regions" { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}
