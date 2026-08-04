data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.aws_account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${var.partition}:ecs:${var.aws_region}:${var.aws_account_id}:*"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "execution" {
  statement {
    sid       = "EcrRegistryToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "PullProjectImages"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid = "WriteApplicationLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${var.log_group_arn}:*"]
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "EcrPullAndApplicationLogs"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  tags               = var.tags
}

locals {
  inference_profile_arn = "arn:${var.partition}:bedrock:${var.aws_region}:${var.aws_account_id}:inference-profile/${var.bedrock_inference_profile_id}"
  foundation_model_arns = [
    for region in var.bedrock_model_regions :
    "arn:${var.partition}:bedrock:${region}::foundation-model/${var.bedrock_foundation_model_id}"
  ]
}

data "aws_iam_policy_document" "task" {
  statement {
    sid = "InvokeNovaLiteOnly"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = concat([local.inference_profile_arn], local.foundation_model_arns)
  }
}

resource "aws_iam_role_policy" "task" {
  name   = "InvokeConfiguredNovaLiteProfile"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task.json
}
