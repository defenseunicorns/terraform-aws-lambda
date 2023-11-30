data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

locals {
  policy_statements = var.is_password_rotation_lambda ? {
    ec2 = {
      effect    = "Allow"
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
    }
    secretsmanager = {
      effect = "Allow"
      actions = [
        "secretsmanager:CreateSecret",
        "secretsmanager:PutResourcePolicy",
        "secretsmanager:DescribeSecret",
        "secretsmanager:UpdateSecret"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
    logs = {
      effect = "Allow"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
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
        "arn:${data.aws_partition.current.partition}:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
        "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:*",
        "arn:${data.aws_partition.current.partition}:ssm:${var.region}::document/AWS-RunShellScript",
        "arn:${data.aws_partition.current.partition}:ssm:${var.region}::document/AWS-RunPowerShellScript"
      ]
    }
  } : {
    a = {
      effect = "Allow"
      actions = [
        "logs:CreateExportTask",
        "logs:Describe*",
        "logs:ListTagsLogGroup"
      ]
      resources = ["*"]
    }
    b = {
      effect = "Allow"
      actions = [
        "ssm:DescribeParameters",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:PutParameter"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/log-exporter-last-export/*"]
    }
    c = {
      effect = "Allow"
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
    d = {
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:PutObjectACL"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.cloudwatch_logs_export_bucket}"]
    }
    e = {
      effect = "Allow"
      actions = [
        "s3:PutBucketAcl",
        "s3:GetBucketAcl"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.cloudwatch_logs_export_bucket}"]
    }
  }
  dynamic_environment_variables = var.is_password_rotation_lambda ? {
    users         = join(",", var.users)
    instance_ids  = join(",", var.instance_ids)
  } : {
    cloudwatch_logs_export_bucket = var.cloudwatch_logs_export_bucket
  }
  static_env_vars = {
    slack_webhook_url          = var.slack_webhook_url
    slack_notification_enabled = var.slack_notification_enabled
  }

}

module "lambda" {
  source        = "git::https://github.com/terraform-aws-modules/terraform-aws-lambda.git?ref=v6.2.0"
  function_name = join("-", [var.name_prefix, var.password_function, var.random_id])
  description   = var.description
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  publish       = true
  allowed_triggers = {
    event_bridge_trigger = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.cron_eventbridge_rule.arn
    }
  }

  environment_variables = merge(
    local.dynamic_environment_variables,
    local.static_env_vars
  )

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
  policy_statements        = local.policy_statements
  source_path = "${path.module}/fixtures/functions/${var.function_name}/lambda_function.py"
}

resource "aws_cloudwatch_event_rule" "cron_eventbridge_rule" {
  name        = join("-", [var.name_prefix, "${var.function_name}-trigger", var.random_id])
  description = "Trigger for lambda function"
  # schedule_expression = "cron(0 0 1 * ? *)"
  schedule_expression = var.cron_schedule
  event_pattern       = <<EOF
{
  "detail-type": [
    "Scheduled Event"
  ],
  "source": [
    "aws.events"
  ],
  "resources": [
    "${module.lambda.lambda_function_arn}"
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "cron_event_target" {
  rule      = aws_cloudwatch_event_rule.cron_eventbridge_rule.name
  target_id = "TargetFunctionV1"
  arn       = module.lambda.lambda_function_arn
}
