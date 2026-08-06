output "bootstrap_role_arn" {
  value = aws_iam_role.bootstrap.arn
}

output "managed_role_names" {
  value = {
    plan   = local.role_names.plan
    deploy = local.role_names.deploy
  }
}
