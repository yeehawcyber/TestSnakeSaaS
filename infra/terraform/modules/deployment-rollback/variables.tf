variable "name_prefix" { type = string }
variable "load_balancer_arn_suffix" { type = string }
variable "target_group_arn_suffix" { type = string }
variable "evaluation_periods" { type = number }
variable "period_seconds" { type = number }
variable "tags" {
  type    = map(string)
  default = {}
}
