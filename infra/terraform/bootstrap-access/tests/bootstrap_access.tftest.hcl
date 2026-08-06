run "bootstrap_access_creation_plan" {
  command = plan

  assert {
    condition     = aws_iam_role.bootstrap.name == "github-actions-testsnakesaas-bootstrap"
    error_message = "The protected bootstrap role name changed unexpectedly."
  }

  assert {
    condition     = aws_iam_role_policy.plan_budget_read.name == "ReadProjectBudgetTags"
    error_message = "The plan-role budget read supplement is missing."
  }

  assert {
    condition     = aws_iam_role_policy.deploy_budget_tags.name == "ManageProjectBudgetTags"
    error_message = "The deploy-role budget tag supplement is missing."
  }
}
