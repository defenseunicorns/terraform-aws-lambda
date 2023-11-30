data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

module "transfer_lambda" {
  source        = "git::https://github.com/terraform-aws-modules/terraform-aws-lambda.git?ref=v6.2.0"
  function_name = join("-", [var.name_prefix, "transfer-function", var.random_id])
  description   = var.description
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  publish       = true
  allowed_triggers = {
    transfer-logs = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.cron_eventbridge_rule.arn
    }
  }
  environment_variables = {
    slack_webhook_url          = var.slack_webhook_url
    slack_notification_enabled = var.slack_notification_enabled
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
  policy_statements = {
    a = {
      effect    = "Allow",
      actions   = [
        "logs:CreateExportTask",
        "logs:Describe*",
        "logs:ListTagsLogGroup"
      ]
      resources = ["*"]
    },
    b = {
      effect = "Allow",
      actions = [
        "ssm:DescribeParameters",
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath",
        "ssm:PutParameter"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/log-exporter-last-export/*"]
    },
    c = {
      effect = "Allow",
      actions = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
    },
    d = {
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:PutObjectACL"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.cloudwatch_logs_export_bucket}"]
    },
    e = {
      effect = "Allow"
      actions = [
        "s3:PutBucketAcl",
        "s3:GetBucketAcl"
      ]
      resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.cloudwatch_logs_export_bucket}"]
    },
  }
  source_path = "${path.module}/fixtures/functions/transfer-logs/lambda_function.py"
}

resource "aws_cloudwatch_event_rule" "cron_eventbridge_rule" {
  name        = join("-", [var.name_prefix, "transfer-function-trigger", var.random_id])
  description = "4 hour trigger for lambda function"
  schedule_expression = var.cron_schedule_logs_transfer
  event_pattern       = <<EOF
{
  "detail-type": [
    "Scheduled Event"
  ],
  "source": [
    "aws.events"
  ],
  "resources": [
    "${module.transfer_lambda.lambda_function_arn}"
  ]
}
EOF
}

resource "aws_cloudwatch_event_target" "cron_event_target" {
  rule      = aws_cloudwatch_event_rule.cron_eventbridge_rule.name
  target_id = "TargetFunctionV1"
  arn       = module.transfer_lambda.lambda_function_arn
}
