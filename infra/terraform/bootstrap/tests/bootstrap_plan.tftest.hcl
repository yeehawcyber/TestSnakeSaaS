run "remote_state_creation_plan" {
  command = plan

  variables {
    state_bucket_name = "testsnakesaas-terraform-state-plan-only"
  }

  assert {
    condition     = module.remote_state.bucket_name == "testsnakesaas-terraform-state-plan-only"
    error_message = "The requested state bucket name was not preserved."
  }
}
