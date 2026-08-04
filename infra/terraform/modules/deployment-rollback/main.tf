resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.name_prefix}-unhealthy-targets"
  alarm_description   = "Roll back an ECS deployment if ALB targets stay unhealthy after the grace period."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = var.period_seconds
  evaluation_periods  = var.evaluation_periods
  datapoints_to_alarm = var.evaluation_periods
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = var.load_balancer_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  tags = var.tags
}
