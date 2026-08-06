module "ecr" {
  source = "./modules/ecr"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "cognito" {
  source = "./modules/cognito"

  name_prefix               = local.name_prefix
  callback_urls             = [var.application_callback_url]
  logout_urls               = [var.application_callback_url]
  cognito_domain_prefix     = var.cognito_domain_prefix
  self_registration_enabled = false
  tags                      = local.common_tags
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 7
  skip_destroy      = false
  tags              = local.common_tags
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name_prefix}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.common_tags
}

locals {
  inference_profile_arn = "arn:${data.aws_partition.current.partition}:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_inference_profile_id}"
  foundation_model_arns = [
    for region in ["us-east-1", "us-east-2", "us-west-2"] :
    "arn:${data.aws_partition.current.partition}:bedrock:${region}::foundation-model/${var.bedrock_foundation_model_id}"
  ]
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid = "WriteApplicationLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.web.arn}:*"]
  }

  statement {
    sid = "InvokeNovaLiteOnly"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = concat([local.inference_profile_arn], local.foundation_model_arns)
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "LogsAndNovaLite"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_lambda_function" "web" {
  function_name = local.function_name
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "${module.ecr.repository_url}:${var.image_tag}"
  architectures = ["x86_64"]

  memory_size                    = 1024
  timeout                        = 30
  reserved_concurrent_executions = 2

  environment {
    variables = {
      AWS_LWA_ASYNC_INIT           = "true"
      AWS_LWA_INVOKE_MODE          = "buffered"
      AWS_LWA_PORT                 = "8080"
      AWS_LWA_READINESS_CHECK_PATH = "/api/health"
      BEDROCK_MODEL_ID             = var.bedrock_inference_profile_id
      COGNITO_CLIENT_ID            = module.cognito.user_pool_client_id
      COGNITO_DOMAIN               = module.cognito.domain_url
      COGNITO_LOGOUT_URI           = var.application_callback_url
      COGNITO_REDIRECT_URI         = var.application_callback_url
      COGNITO_USER_POOL_ID         = module.cognito.user_pool_id
      NODE_ENV                     = "production"
      PORT                         = "8080"
    }
  }

  logging_config {
    application_log_level = "INFO"
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.web.name
    system_log_level      = "WARN"
  }

  tags = local.common_tags

  depends_on = [aws_iam_role_policy.lambda]
}

resource "aws_apigatewayv2_api" "web" {
  name          = "${local.name_prefix}-web"
  protocol_type = "HTTP"
  description   = "Cost-bounded HTTPS endpoint for TestSnakeSaaS dev"
  tags          = local.common_tags
}

resource "aws_apigatewayv2_integration" "web" {
  api_id                 = aws_apigatewayv2_api.web.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.web.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.web.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.web.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.web.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    detailed_metrics_enabled = false
    throttling_burst_limit   = 4
    throttling_rate_limit    = 2
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.web.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.web.execution_arn}/*/*"
}

resource "aws_budgets_budget" "monthly_account" {
  name         = "${local.name_prefix}-monthly-account-cost"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_alert_email == null ? [] : [var.budget_alert_email]
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_guard.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_alert_email == null ? [] : [var.budget_alert_email]
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_guard.arn]
  }

  tags = local.common_tags
}

resource "aws_sns_topic" "cost_guard" {
  name              = "${local.name_prefix}-cost-guard"
  kms_master_key_id = "alias/aws/sns"
  tags              = local.common_tags
}

data "aws_iam_policy_document" "cost_guard_topic" {
  statement {
    sid       = "AllowAwsBudgets"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.cost_guard.arn]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "cost_guard" {
  arn    = aws_sns_topic.cost_guard.arn
  policy = data.aws_iam_policy_document.cost_guard_topic.json
}

resource "aws_cloudwatch_log_group" "cost_guard" {
  name              = "/aws/lambda/${local.name_prefix}-cost-guard"
  retention_in_days = 7
  tags              = local.common_tags
}

resource "aws_iam_role" "cost_guard" {
  name               = "${local.name_prefix}-cost-guard"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "cost_guard" {
  statement {
    sid = "WriteGuardLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.cost_guard.arn}:*"]
  }

  statement {
    sid       = "DisableOnlyWebFunction"
    actions   = ["lambda:PutFunctionConcurrency"]
    resources = [aws_lambda_function.web.arn]
  }
}

resource "aws_iam_role_policy" "cost_guard" {
  name   = "LogsAndDisableWebFunction"
  role   = aws_iam_role.cost_guard.id
  policy = data.aws_iam_policy_document.cost_guard.json
}

data "archive_file" "cost_guard" {
  type        = "zip"
  source_file = "${path.module}/cost-guard/index.mjs"
  output_path = "${path.module}/.terraform/cost-guard.zip"
}

resource "aws_lambda_function" "cost_guard" {
  function_name = "${local.name_prefix}-cost-guard"
  role          = aws_iam_role.cost_guard.arn
  runtime       = "nodejs22.x"
  handler       = "index.handler"

  filename         = data.archive_file.cost_guard.output_path
  source_code_hash = data.archive_file.cost_guard.output_base64sha256

  memory_size                    = 128
  timeout                        = 10
  reserved_concurrent_executions = 1

  environment {
    variables = {
      TARGET_FUNCTION = aws_lambda_function.web.function_name
    }
  }

  logging_config {
    application_log_level = "INFO"
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.cost_guard.name
    system_log_level      = "WARN"
  }

  tags       = local.common_tags
  depends_on = [aws_iam_role_policy.cost_guard]
}

resource "aws_lambda_permission" "cost_guard_sns" {
  statement_id  = "AllowCostGuardSnsInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_guard.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.cost_guard.arn
}

resource "aws_sns_topic_subscription" "cost_guard" {
  topic_arn = aws_sns_topic.cost_guard.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.cost_guard.arn

  depends_on = [aws_lambda_permission.cost_guard_sns]
}
