data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  # This data source provides information on the IAM source role of an STS assumed role
  # For non-role ARNs, this data source simply passes the ARN through issuer ARN
  # Ref https://github.com/terraform-aws-modules/terraform-aws-eks/issues/2327#issuecomment-1355581682
  # Ref https://github.com/hashicorp/terraform-provider-aws/issues/28381
  arn = data.aws_caller_identity.current.arn
}

module "password_lambda" {
  source        = "git::https://github.com/terraform-aws-modules/terraform-aws-lambda.git?ref=v7.2.6"
  function_name = join("-", compact([var.prefix, "password-rotation-function", var.suffix]))
  description   = var.description
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  publish       = true
  allowed_triggers = {
    password-rotation = {
      principal  = "secretsmanager.amazonaws.com"
      source_arn = module.secrets_manager.secret_arn
    }
  }

  environment_variables = {
    USERS              = join(",", var.users) # takes a list of users and joins them into a comma separated string
    ROTATION_TAG_KEY   = var.rotation_tag_key
    ROTATION_TAG_VALUE = var.rotation_tag_value
    WEBHOOK_URL        = var.notification_webhook_url
    WEBHOOK_SECRET_ID  = var.notification_webhook_secret_id
  }

  assume_role_policy_statements = {
    account_root = {
      effect  = "Allow",
      actions = ["sts:AssumeRole"],
      principals = {
        account_principal = {
          type        = "Service",
          identifiers = ["lambda.amazonaws.com"]
        }
      }
    }
  }
  attach_policy_statements = true
  policy_statements = merge(
    var.lambda_additional_policy_statements,
    {
      ec2 = {
        effect    = "Allow",
        actions   = ["ec2:DescribeInstances", "ec2:DescribeImages"]
        resources = ["*"]
        condition = {
          stringequals_condition = {
            test     = "StringEquals"
            variable = "aws:RequestedRegion"
            values   = [var.region]
          }
          stringequals_condition2 = {
            test     = "StringEquals"
            variable = "aws:PrincipalAccount"
            values   = [data.aws_caller_identity.current.account_id]
          }
        }
      },
      targeted_secretsmanager = {
        effect = "Allow",
        actions = [
          "secretsmanager:CreateSecret",
          "secretsmanager:PutResourcePolicy",
          "secretsmanager:DescribeSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:RotateSecret"
        ]
        resources = [module.secrets_manager.secret_arn]
      },
      general_secretsmanager = {
        effect = "Allow",
        actions = [
          "secretsmanager:GetRandomPassword"
        ]
        resources = ["*"]
      }
      logs = {
        effect = "Allow",
        actions = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        resources = ["arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
      },
      ssm = {
        effect = "Allow"
        actions = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:DeleteParameter"
        ]
        resources = [
          #should be variable passed in per instance.
          "arn:${data.aws_partition.current.partition}:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:*",
          "arn:${data.aws_partition.current.partition}:ssm:${var.region}::document/AWS-RunShellScript",
          "arn:${data.aws_partition.current.partition}:ssm:${var.region}::document/AWS-RunPowerShellScript"
        ]
      },
    }
  )
  source_path = "${path.module}/fixtures/functions/password-rotation/lambda_function.py"
}

locals {
  secrets_manager_secret_name_use_prefix = var.secrets_manager_secret_name == null || var.secrets_manager_secret_name == "" ? true : false
  secrets_manager_secret_name_prefix     = join("-", compact([var.prefix, var.secrets_manager_secret_name_prefix]))

  secret_string = coalesce(var.initial_secret_json_value, jsonencode({ ec2-user = random_password.initial-secret-password.result }))
  current_context_access_secret = var.allow_current_context_to_access_secret ? {
    current_context_read = {
      sid = "AllowCurrentContextRead"
      principals = [{
        type        = "AWS"
        identifiers = [data.aws_iam_session_context.current.issuer_arn]
      }]
      actions   = ["secretsmanager:DescribeSecret"]
      resources = ["*"]
    }
  } : {}
}

# generate a random password in terraform
resource "random_password" "initial-secret-password" {
  length           = 32
  special          = true
  override_special = "!%^&*()_+"

  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
}

module "secrets_manager" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-secrets-manager.git?ref=v1.1.2"

  # Secret
  name                    = local.secrets_manager_secret_name_use_prefix ? null : var.secrets_manager_secret_name
  name_prefix             = local.secrets_manager_secret_name_use_prefix ? local.secrets_manager_secret_name_prefix : null
  description             = var.secrets_manager_secret_description
  recovery_window_in_days = var.recovery_window_in_days

  # Policy
  create_policy       = true
  block_public_policy = true
  policy_statements = merge(
    local.current_context_access_secret,
    var.secrets_manager_additional_policy_statements, # add any additional policy statements - suchas allowing some other role to read/write the secret
    {
      lambda = {
        sid = "LambdaReadWrite"
        principals = [{
          type        = "AWS"
          identifiers = [module.password_lambda.lambda_role_arn]
        }]
        actions = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
        ]
        resources = ["*"]
      }
    }
  )

  # Version
  ignore_secret_changes = true
  secret_string         = local.secret_string

  # Rotation
  enable_rotation     = true
  rotation_lambda_arn = module.password_lambda.lambda_function_arn
  rotation_rules      = var.rotation_rules

  tags = var.tags
}
