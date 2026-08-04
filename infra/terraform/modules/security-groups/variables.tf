variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "container_port" { type = number }
variable "allowed_ingress_cidrs" { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}
