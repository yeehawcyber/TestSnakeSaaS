output "alarm_names" { value = [aws_cloudwatch_metric_alarm.unhealthy_targets.alarm_name] }
