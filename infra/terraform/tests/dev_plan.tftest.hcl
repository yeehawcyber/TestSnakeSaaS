run "dev_creation_plan" {
  command = plan

  variables {
    cognito_domain_prefix = "testsnakesaas-dev-plan-only"
    image_tag             = "0000000000000000000000000000000000000000"
  }

  assert {
    condition     = aws_lambda_function.web.function_name == "testsnakesaas-dev-web"
    error_message = "The dev Lambda function name changed unexpectedly."
  }

  assert {
    condition     = aws_lambda_function.web.reserved_concurrent_executions == 2
    error_message = "The cost-control concurrency bound changed unexpectedly."
  }

  assert {
    condition     = aws_budgets_budget.monthly_account.limit_amount == "10"
    error_message = "The monthly account budget must remain USD 10."
  }

  assert {
    condition     = aws_lambda_function.cost_guard.reserved_concurrent_executions == 1
    error_message = "The budget guard Lambda must retain bounded concurrency."
  }

  assert {
    condition     = module.cognito.self_registration_enabled
    error_message = "The dev user pool must allow new players to self-register."
  }
}
