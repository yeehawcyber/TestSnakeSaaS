output "state_bucket_name" { value = module.remote_state.bucket_name }
output "state_bucket_arn" { value = module.remote_state.bucket_arn }
output "state_kms_key_arn" { value = module.remote_state.kms_key_arn }
output "github_plan_role_arn" { value = module.github_actions.plan_role_arn }
output "github_deploy_role_arn" { value = module.github_actions.deploy_role_arn }

output "backend_hcl" {
  description = "Non-secret partial backend configuration for the application dev root."
  value       = <<-EOT
    bucket       = "${module.remote_state.bucket_name}"
    key          = "testsnakesaas/dev/terraform.tfstate"
    region       = "${var.aws_region}"
    encrypt      = true
    kms_key_id   = "${module.remote_state.kms_key_arn}"
    use_lockfile = true
  EOT
}

output "bootstrap_backend_hcl" {
  description = "Non-secret partial backend configuration used after creation to migrate the bootstrap state."
  value       = <<-EOT
    bucket       = "${module.remote_state.bucket_name}"
    key          = "testsnakesaas/bootstrap/terraform.tfstate"
    region       = "${var.aws_region}"
    encrypt      = true
    kms_key_id   = "${module.remote_state.kms_key_arn}"
    use_lockfile = true
  EOT
}
