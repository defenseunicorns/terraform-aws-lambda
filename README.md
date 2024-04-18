# AWS Lambda Module

This repository contains Lambda modules that are deployed using Terraform.

## Usage

If you want to create new functionality, you can do so by writing your lambda code and storing it in its own directory. For example, the code for the password rotation function can be stored in the directory `fixtures/functions/password-rotation/lambda_function.py`. In your `main.tf` file, use the following `source_path`:

`source_path = "${path.module}/fixtures/functions/password-rotation/lambda_function.py"`

### Lambda Password Module

This module deploys a Python function that securely generates and rotates EC2 instance passwords for EC2 Linux instances using AWS Systems Manager (SSM), Secrets Manager, and Lambda. The function is triggered by the [builtin Secrets Manager secret rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html) process

#### Example

To see an example of how to leverage this Lambda Module, please refer to the [examples](https://github.com/defenseunicorns/delivery-aws-iac/tree/main/examples) directory.

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
| <a name="module_password_lambda"></a> [password\_lambda](#module\_password\_lambda) | git::<https://github.com/terraform-aws-modules/terraform-aws-lambda.git> | v6.0.0 |

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
| <a name="input_cron_schedule_password_rotation"></a> [cron\_schedule\_password\_rotation](#input\_cron\_schedule\_password\_rotation) | Schedule for password change function to run on | `string` | `"cron(0 0 1 * ? *)"` | no |
| <a name="input_instance_ids"></a> [instance\_ids](#input\_instance\_ids) | List of instances that passwords will be rotated by lambda function | `list(string)` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name prefix for all resources that use a randomized suffix | `string` | n/a | yes |
| <a name="input_random_id"></a> [random\_id](#input\_random\_id) | random it for unique naming | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_slack_notification_enabled"></a> [slack\_notification\_enabled](#input\_slack\_notification\_enabled) | enable slack notifications for password rotation function. If enabled a slack webhook url will also need to be provided for this to work | `bool` | `false` | no |
| <a name="input_slack_webhook_url"></a> [slack\_webhook\_url](#input\_slack\_webhook\_url) | value | `string` | `null` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users to change passwords for password lambda function | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_password_function_arn"></a> [lambda\_password\_function\_arn](#output\_lambda\_password\_function\_arn) | Arn for lambda password function |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
