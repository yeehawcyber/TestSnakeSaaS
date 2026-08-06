resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.tags
}

locals {
  state_arn = "${var.state_bucket_arn}/${var.state_key}"
  lock_arn  = "${local.state_arn}.tflock"
  ecr_arn   = "arn:${var.partition}:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.name_prefix}-web"
  lambda_arns = [
    "arn:${var.partition}:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.name_prefix}-web",
    "arn:${var.partition}:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.name_prefix}-cost-guard",
  ]
  lambda_role_arns = [
    "arn:${var.partition}:iam::${var.aws_account_id}:role/${var.name_prefix}-lambda",
    "arn:${var.partition}:iam::${var.aws_account_id}:role/${var.name_prefix}-cost-guard",
  ]
  log_group_arns = [
    "arn:${var.partition}:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.name_prefix}-web",
    "arn:${var.partition}:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/lambda/${var.name_prefix}-cost-guard",
  ]
  cost_guard_topic_arn = "arn:${var.partition}:sns:${var.aws_region}:${var.aws_account_id}:${var.name_prefix}-cost-guard"
  budget_arn           = "arn:${var.partition}:budgets::${var.aws_account_id}:budget/${var.name_prefix}-monthly-account-cost"
  api_gateway_arns     = ["arn:${var.partition}:apigateway:${var.aws_region}::/*"]
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${var.github_oidc_subject_prefix}:pull_request",
        "${var.github_oidc_subject_prefix}:ref:refs/heads/main",
      ]
    }
  }
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
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

resource "aws_iam_role" "plan" {
  name                 = "github-actions-${var.name_prefix}-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
  tags                 = merge(var.tags, { Purpose = "Read-only Terraform plans" })
}

resource "aws_iam_role" "deploy" {
  name                 = "github-actions-${var.name_prefix}-deploy"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600
  tags                 = merge(var.tags, { Purpose = "Approval-gated dev deployment" })
}

data "aws_iam_policy_document" "plan_state" {
  statement {
    sid       = "ListProjectState"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]

    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = [var.state_key]
    }
  }

  statement {
    sid       = "ReadProjectState"
    actions   = ["s3:GetObject"]
    resources = [local.state_arn]
  }

  statement {
    sid       = "DecryptProjectState"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.state_kms_key_arn]
  }
}

data "aws_iam_policy_document" "deploy_state" {
  source_policy_documents = [data.aws_iam_policy_document.plan_state.json]

  statement {
    sid       = "WriteProjectState"
    actions   = ["s3:PutObject"]
    resources = [local.state_arn]
  }

  statement {
    sid       = "ManageProjectStateLock"
    actions   = ["s3:DeleteObject", "s3:GetObject", "s3:PutObject"]
    resources = [local.lock_arn]
  }

  statement {
    sid       = "EncryptProjectState"
    actions   = ["kms:Encrypt", "kms:GenerateDataKey"]
    resources = [var.state_kms_key_arn]
  }
}

data "aws_iam_policy_document" "read_infrastructure" {
  statement {
    sid = "ReadDevInfrastructure"
    actions = [
      "apigateway:GET",
      "budgets:ViewBudget",
      "cognito-idp:DescribeUserPool",
      "cognito-idp:DescribeUserPoolClient",
      "cognito-idp:DescribeUserPoolDomain",
      "cognito-idp:GetUserPoolMfaConfig",
      "cognito-idp:ListTagsForResource",
      "cognito-idp:ListUserPoolClients",
      "cognito-idp:ListUserPools",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:ListTagsForResource",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
      "lambda:GetFunction",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionConcurrency",
      "lambda:GetFunctionUrlConfig",
      "lambda:GetPolicy",
      "lambda:GetRuntimeManagementConfig",
      "lambda:ListVersionsByFunction",
      "lambda:ListTags",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "sns:GetSubscriptionAttributes",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "TerraformState"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

resource "aws_iam_role_policy" "plan_read" {
  name   = "ReadDevInfrastructure"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.read_infrastructure.json
}

resource "aws_iam_role_policy" "deploy_state" {
  name   = "TerraformState"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_state.json
}

resource "aws_iam_role_policy" "deploy_read" {
  name   = "ReadDevInfrastructure"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.read_infrastructure.json
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid = "PublishDeploymentImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [local.ecr_arn]
  }

  statement {
    sid       = "GetEcrRegistryToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ManageEcrConfiguration"
    actions = [
      "ecr:CreateRepository",
      "ecr:DeleteLifecyclePolicy",
      "ecr:DeleteRepository",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:PutLifecyclePolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
    ]
    resources = [local.ecr_arn]
  }

  statement {
    sid = "ManageLambda"
    actions = [
      "lambda:AddPermission",
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:DeleteFunctionConcurrency",
      "lambda:PutFunctionConcurrency",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
    ]
    resources = local.lambda_arns
  }

  statement {
    sid = "ManageLambdaRole"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
    ]
    resources = local.lambda_role_arns
  }

  statement {
    sid       = "PassLambdaRoleOnly"
    actions   = ["iam:PassRole"]
    resources = local.lambda_role_arns

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid = "ManageLambdaLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DeleteRetentionPolicy",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = concat(local.log_group_arns, [for arn in local.log_group_arns : "${arn}:*"])
  }

  statement {
    sid       = "ManageHttpApi"
    actions   = ["apigateway:DELETE", "apigateway:PATCH", "apigateway:POST", "apigateway:PUT"]
    resources = local.api_gateway_arns
  }

  statement {
    sid = "ManageCognito"
    actions = [
      "cognito-idp:CreateUserPool",
      "cognito-idp:CreateUserPoolClient",
      "cognito-idp:CreateUserPoolDomain",
      "cognito-idp:DeleteUserPool",
      "cognito-idp:DeleteUserPoolClient",
      "cognito-idp:DeleteUserPoolDomain",
      "cognito-idp:SetUserPoolMfaConfig",
      "cognito-idp:TagResource",
      "cognito-idp:UntagResource",
      "cognito-idp:UpdateUserPool",
      "cognito-idp:UpdateUserPoolClient",
    ]
    resources = ["arn:${var.partition}:cognito-idp:${var.aws_region}:${var.aws_account_id}:userpool/*"]
  }

  statement {
    sid       = "ManageDevBudget"
    actions   = ["budgets:ModifyBudget"]
    resources = [local.budget_arn]
  }

  statement {
    sid = "ManageCostGuardTopic"
    actions = [
      "sns:AddPermission",
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:RemovePermission",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:TagResource",
      "sns:UntagResource",
    ]
    resources = [local.cost_guard_topic_arn]
  }

  statement {
    sid       = "ManageCostGuardSubscription"
    actions   = ["sns:SetSubscriptionAttributes", "sns:Unsubscribe"]
    resources = ["${local.cost_guard_topic_arn}:*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "ManageServerlessDev"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
