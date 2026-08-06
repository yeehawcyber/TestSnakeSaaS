locals {
  name_prefix = "testsnakesaas"
  role_names = {
    bootstrap = "github-actions-${local.name_prefix}-bootstrap"
    plan      = "github-actions-${local.name_prefix}-dev-plan"
    deploy    = "github-actions-${local.name_prefix}-dev-deploy"
  }
  role_arns = {
    for name, role_name in local.role_names :
    name => "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/${role_name}"
  }
  oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
  state_bucket_arn  = "arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket_name}"
  state_keys = [
    "testsnakesaas/bootstrap/terraform.tfstate",
    "testsnakesaas/bootstrap-access/terraform.tfstate",
  ]
  state_object_arns = [for key in local.state_keys : "${local.state_bucket_arn}/${key}"]
  state_lock_arns   = [for key in local.state_keys : "${local.state_bucket_arn}/${key}.tflock"]
  budget_arn        = "arn:${data.aws_partition.current.partition}:budgets::${var.aws_account_id}:budget/testsnakesaas-dev-monthly-account-cost"
  tags = {
    Application = "testsnakesaas"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Purpose     = "GitHub Actions bootstrap control plane"
    Repository  = "yeehawcyber/TestSnakeSaaS"
  }
}

data "aws_iam_policy_document" "bootstrap_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${var.github_oidc_subject_prefix}:environment:${var.github_environment}"]
    }
  }
}

resource "aws_iam_role" "bootstrap" {
  name                 = local.role_names.bootstrap
  assume_role_policy   = data.aws_iam_policy_document.bootstrap_trust.json
  max_session_duration = 3600
  tags                 = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "bootstrap" {
  statement {
    sid       = "ListBootstrapState"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]

    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = concat(local.state_keys, [for key in local.state_keys : "${key}.tflock"])
    }
  }

  statement {
    sid       = "ManageBootstrapStateObjects"
    actions   = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"]
    resources = concat(local.state_object_arns, local.state_lock_arns)
  }

  statement {
    sid = "EncryptBootstrapState"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.state_kms_key_arn]
  }

  statement {
    sid = "ReadBootstrapRoleWithoutSelfMutation"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
    ]
    resources = [local.role_arns.bootstrap]
  }

  statement {
    sid = "ManageOnlyGitHubPlanAndDeployRoles"
    actions = [
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = [local.role_arns.plan, local.role_arns.deploy]
  }

  statement {
    sid = "ReadGitHubOidcProvider"
    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviderTags",
    ]
    resources = [local.oidc_provider_arn]
  }
}

resource "aws_iam_role_policy" "bootstrap" {
  name   = "BootstrapControlPlane"
  role   = aws_iam_role.bootstrap.id
  policy = data.aws_iam_policy_document.bootstrap.json

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "plan_budget_read" {
  statement {
    sid       = "ReadProjectBudgetTags"
    actions   = ["budgets:ListTagsForResource"]
    resources = [local.budget_arn]
  }
}

resource "aws_iam_role_policy" "plan_budget_read" {
  name   = "ReadProjectBudgetTags"
  role   = local.role_names.plan
  policy = data.aws_iam_policy_document.plan_budget_read.json
}

data "aws_iam_policy_document" "deploy_budget_tags" {
  source_policy_documents = [data.aws_iam_policy_document.plan_budget_read.json]

  statement {
    sid       = "ManageProjectBudgetTags"
    actions   = ["budgets:TagResource", "budgets:UntagResource"]
    resources = [local.budget_arn]
  }
}

resource "aws_iam_role_policy" "deploy_budget_tags" {
  name   = "ManageProjectBudgetTags"
  role   = local.role_names.deploy
  policy = data.aws_iam_policy_document.deploy_budget_tags.json
}
