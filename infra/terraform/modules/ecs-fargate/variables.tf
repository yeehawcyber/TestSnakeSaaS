variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "task_security_group_id" { type = string }
variable "target_group_arn" { type = string }
variable "repository_url" { type = string }
variable "image_tag" { type = string }
variable "execution_role_arn" { type = string }
variable "task_role_arn" { type = string }
variable "log_group_name" { type = string }
variable "desired_count" { type = number }
variable "rollback_alarm_names" {
  type    = list(string)
  default = []
}
variable "environment_variables" { type = map(string) }
variable "tags" {
  type    = map(string)
  default = {}
}
