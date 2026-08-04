resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.tags
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn
  state_arn         = "${var.state_bucket_arn}/${var.state_key}"
  lock_arn          = "${local.state_arn}.tflock"
  role_path_arn     = "arn:${var.partition}:iam::${var.aws_account_id}:role/${var.name_prefix}-*"
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

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
      values   = ["${var.github_oidc_subject_prefix}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "github-actions-${var.name_prefix}-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
  tags                 = merge(var.tags, { Purpose = "Pull request Terraform plan" })
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

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

resource "aws_iam_role" "deploy" {
  name                 = "github-actions-${var.name_prefix}-deploy"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600
  tags                 = merge(var.tags, { Purpose = "Approval-gated dev deployment" })
}

data "aws_iam_policy_document" "plan_state" {
  statement {
    sid       = "ListOnlyProjectState"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]

    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = [var.state_key]
    }
  }

  statement {
    sid       = "ReadOnlyProjectState"
    actions   = ["s3:GetObject"]
    resources = [local.state_arn]
  }

  statement {
    sid = "DecryptProjectState"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [var.state_kms_key_arn]
  }
}

data "aws_iam_policy_document" "deploy_state" {
  source_policy_documents = [data.aws_iam_policy_document.plan_state.json]

  statement {
    sid       = "ListProjectStateLock"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]

    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = ["${var.state_key}.tflock"]
    }
  }

  statement {
    sid       = "WriteProjectState"
    actions   = ["s3:PutObject"]
    resources = [local.state_arn]
  }

  statement {
    sid = "ManageProjectStateLock"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [local.lock_arn]
  }

  statement {
    sid = "EncryptProjectStateAndLock"
    actions = [
      "kms:Encrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.state_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "TerraformState"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

resource "aws_iam_role_policy" "deploy_state" {
  name   = "TerraformState"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_state.json
}

data "aws_iam_policy_document" "read_infrastructure" {
  statement {
    sid = "ReadProjectInfrastructure"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:ListTagsForCertificate",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource",
      "cognito-idp:DescribeUserPool",
      "cognito-idp:DescribeUserPoolClient",
      "cognito-idp:DescribeUserPoolDomain",
      "cognito-idp:GetUserPoolMfaConfig",
      "cognito-idp:ListTagsForResource",
      "cognito-idp:ListUserPoolClients",
      "cognito-idp:ListUserPools",
      "ec2:Describe*",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:ListTagsForResource",
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:ListClusters",
      "ecs:ListServices",
      "ecs:ListTagsForResource",
      "ecs:ListTaskDefinitions",
      "elasticloadbalancing:Describe*",
      "iam:GetOpenIDConnectProvider",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListOpenIDConnectProviderTags",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "plan_read" {
  name   = "ReadDevInfrastructure"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.read_infrastructure.json
}

resource "aws_iam_role_policy" "deploy_read" {
  name   = "ReadDevInfrastructure"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.read_infrastructure.json
}

data "aws_iam_policy_document" "deploy_network_compute" {
  statement {
    sid = "ManageDevNetworking"
    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:CreateVpcEndpoint",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteNatGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVpc",
      "ec2:DeleteVpcEndpoints",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateRouteTable",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ModifyVpcEndpoint",
      "ec2:ReleaseAddress",
      "ec2:ReplaceRoute",
      "ec2:ReplaceRouteTableAssociation",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid = "ManageDevEcs"
    actions = [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecs:DeleteCluster",
      "ecs:DeleteService",
      "ecs:DeregisterTaskDefinition",
      "ecs:PutClusterCapacityProviders",
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource",
      "ecs:UntagResource",
      "ecs:UpdateCluster",
      "ecs:UpdateClusterSettings",
      "ecs:UpdateService",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid = "ManageDevLoadBalancing"
    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }
}

resource "aws_iam_role_policy" "deploy_network_compute" {
  name   = "ManageDevNetworkAndCompute"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_network_compute.json
}

data "aws_iam_policy_document" "deploy_application_services" {
  statement {
    sid = "CreateAndManageDevEcr"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:CreateRepository",
      "ecr:DeleteLifecyclePolicy",
      "ecr:DeleteRepository",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:PutLifecyclePolicy",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:UploadLayerPart",
    ]
    resources = ["*", var.ecr_repository_arn]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid       = "GetEcrRegistryToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ManageDevLogsAndAlarms"
    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DeleteRetentionPolicy",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid = "ManageDevCertificate"
    actions = [
      "acm:AddTagsToCertificate",
      "acm:DeleteCertificate",
      "acm:RemoveTagsFromCertificate",
      "acm:RequestCertificate",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  statement {
    sid = "ManageApplicationDns"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["arn:${var.partition}:route53:::hostedzone/${var.route53_zone_id}"]
  }

  statement {
    sid       = "WaitForDnsChange"
    actions   = ["route53:GetChange"]
    resources = ["arn:${var.partition}:route53:::change/*"]
  }

  statement {
    sid = "ManageDevCognito"
    actions = [
      "cognito-idp:CreateUserPool",
      "cognito-idp:CreateUserPoolClient",
      "cognito-idp:CreateUserPoolDomain",
      "cognito-idp:DeleteUserPoolClient",
      "cognito-idp:DeleteUserPoolDomain",
      "cognito-idp:SetUserPoolMfaConfig",
      "cognito-idp:TagResource",
      "cognito-idp:UntagResource",
      "cognito-idp:UpdateUserPool",
      "cognito-idp:UpdateUserPoolClient",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }
}

resource "aws_iam_role_policy" "deploy_application_services" {
  name   = "ManageDevApplicationServices"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_application_services.json
}

data "aws_iam_policy_document" "deploy_project_roles" {
  statement {
    sid = "ManageOnlyEcsRuntimeRoles"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription",
    ]
    resources = [var.ecs_execution_role_arn, var.ecs_task_role_arn]
  }

  statement {
    sid       = "PassOnlyEcsRuntimeRoles"
    actions   = ["iam:PassRole"]
    resources = [var.ecs_execution_role_arn, var.ecs_task_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    sid       = "CreateRequiredServiceLinkedRoles"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "ecs.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "deploy_project_roles" {
  name   = "ManageEcsRuntimeRolesOnly"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy_project_roles.json
}
