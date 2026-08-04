resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name_prefix}-web"
  retention_in_days = var.retention_in_days
  skip_destroy      = false
  tags              = var.tags
}
