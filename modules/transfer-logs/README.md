# password-rotation

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.62.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.62.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_transfer_lambda"></a> [transfer\_lambda](#module\_transfer\_lambda) | git::https://github.com/terraform-aws-modules/terraform-aws-lambda.git | v6.2.0 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.cron_eventbridge_rule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.cron_event_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudwatch_logs_export_bucket"></a> [cloudwatch\_logs\_export\_bucket](#input\_cloudwatch\_logs\_export\_bucket) | Bucket to target for exporting logs | `string` | `""` | no |
| <a name="input_cron_schedule_logs_transfer"></a> [cron\_schedule\_logs\_transfer](#input\_cron\_schedule\_logs\_transfer) | Schedule for transfer logs function to run on | `string` | `"cron(0 */4 * * ? *)"` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the lambda function | `string` | `"Lambda Function that performs some predefined action"` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Handler for the lambda function | `string` | `"lambda_function.lambda_handler"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name prefix for all resources that use a randomized suffix | `string` | n/a | yes |
| <a name="input_random_id"></a> [random\_id](#input\_random\_id) | random id for unique naming | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Runtime for the lambda function | `string` | `"python3.9"` | no |
| <a name="input_slack_notification_enabled"></a> [slack\_notification\_enabled](#input\_slack\_notification\_enabled) | enable slack notifications for transfer logs function. If enabled a slack webhook url will also need to be provided for this to work | `bool` | `false` | no |
| <a name="input_slack_webhook_url"></a> [slack\_webhook\_url](#input\_slack\_webhook\_url) | value | `string` | `null` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Timeout for the lambda function | `number` | `900` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_transfer_function_arn"></a> [lambda\_transfer\_function\_arn](#output\_lambda\_transfer\_function\_arn) | Arn for lambda transfer function |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
