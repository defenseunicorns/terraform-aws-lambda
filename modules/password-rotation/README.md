# AWS Lambda Function for Password Rotation

This module creates a Secrets Manager secret and a Lambda function to rotate the secret. The Lambda is triggered by the [Secrets Manager password rotation process](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotate-secrets_lambda-functions.html) and it is triggered by a schedule.

The terraform creates the initial secret value using the `random_password` resource, and the secret is stored in Secrets Manager. The Lambda function is created using the `password_lambda` module.

## Functionality

This Lambda function interacts with AWS Secrets Manager and other AWS services to automate the process of rotating passwords. It is triggered by a specific rotation event and follows these steps:

1. **Create Secret:** Generate a new password for each user and stages it as `AWSPENDING`. If an `AWSPENDING` version already exists, it is retrieved; otherwise, a new one is created.
2. **Set Secret:** No operation is performed at this step but it's reserved for operations like setting the secret on a database or service.
3. **Test Secret:** This step is reserved for testing the new secret to ensure it works as expected in the target system. No operation is performed at this stage.
4. **Finish Secret:** The new secret version is set as `AWSCURRENT`, finalizing the rotation. Additionally, EC2 instances are updated using AWS Systems Manager (SSM) to use the newly rotated password.

## Exception Handling

The function includes robust error handling, logging the event details and providing detailed error messages. It constructs and logs AWS CLI commands to retrieve logs for deeper investigation.

## Notifications

The function can send notifications to a specified webhook URL upon completion or failure of the secret rotation process. It uses environment variables to manage notification settings. This is optional and can be configured as needed.

## Environment Variables

This Lambda function utilizes the following environment variables:

- `USERS` **(Required)**: List of usernames for which passwords are rotated for each instance sent via SSM command. The function rotates the password for each user in the list.
- `ROTATION_TAG_KEY` **(Required)**: Key for the tag used to identify EC2 instances for password updates.
- `ROTATION_TAG_VALUE` **(Required)**: Value for the tag used to identify EC2 instances for password updates.
- `EXCLUDE_CHARACTERS`: Characters to exclude from generated passwords.
- `SECRETS_MANAGER_ENDPOINT`: Endpoint URL for the Secrets Manager service.
- `SSM_ENDPOINT`: Endpoint URL for the Systems Manager service.
- `WEBHOOK_SECRET_ID`: Secrets Manager secret ID where the webhook URL is stored. Ensure the Lambda function has permission to access the secret.
- `WEBHOOK_URL`: Webhook URL to send notifications to. Not recommended to store the URL directly in the function's environment variables. Recommended to use `WEBHOOK_SECRET_ID`.

Currently, only `USERS`, `ROTATION_TAG_KEY`, and `ROTATION_TAG_VALUE`, `NOTIFICATION_WEBHOOK_URL`, and `NOTIFICATION_WEBHOOK_SECRET_ID` are configurable through this terraform module.

- `USERS`: maps to `var.users`
- `ROTATION_TAG_KEY`: maps to `var.rotation_tag_key`
- `ROTATION_TAG_VALUE`: maps to `var.rotation_tag_value`
- `NOTIFICATION_WEBHOOK_URL`: maps to `var.notification_webhook_url`
- `NOTIFICATION_WEBHOOK_SECRET_ID`: maps to `var.notification_webhook_secret_id`

## Requirements

- AWS SDK for Python (Boto3)
- Python 3.8 or later

## Deployment

See [example terraform deployment here](../../examples/complete)

### Permissions for notifcation_webhook_secret_id (WEBHOOK_SECRET_ID) example

Assume that a secret is staged in AWS Secrets Manager with the webhook URL.

Additional permissions can be set via `lambda_additional_policy_statements` when calling this module:

```hcl
### fetch secretsmanager secret for the notifcation webhook
data "aws_secretsmanager_secret" "narwhal-bot-slack-webhook" {
  count = var.notification_webhook_secret_id != "" ? 1 : 0
  name  = var.notification_webhook_secret_id
}

module "password_lambda" {
  source = "git::https://github.com/defenseunicorns/terraform-aws-lambda.git//modules/password-rotation?ref=v0.0.5"
  region = var.region
  suffix = lower(random_id.default.hex)
  prefix = local.prefix
  users  = var.users
  lambda_additional_policy_statements = {
    webhook_secret_fetcher = {
      effect    = "Allow",
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [data.aws_secretsmanager_secret.narwhal-bot-slack-webhook[0].arn]
    }
  }

  notification_webhook_secret_id = data.aws_secretsmanager_secret.narwhal-bot-slack-webhook[0].arn
  rotation_tag_key               = "Password-Rotation"
  rotation_tag_value             = "enabled"
}
```

## Logging

Logs are essential for monitoring the behavior of the Lambda function and are particularly useful for debugging issues related to the rotation process.

For more detailed usage and troubleshooting, please refer to the function code and associated AWS documentation.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.62.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.62.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.1.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_password_lambda"></a> [password\_lambda](#module\_password\_lambda) | git::https://github.com/terraform-aws-modules/terraform-aws-lambda.git | v7.2.6 |
| <a name="module_secrets_manager"></a> [secrets\_manager](#module\_secrets\_manager) | git::https://github.com/terraform-aws-modules/terraform-aws-secrets-manager.git | v1.1.2 |

## Resources

| Name | Type |
|------|------|
| [random_password.initial-secret-password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_session_context) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_current_context_to_access_secret"></a> [allow\_current\_context\_to\_access\_secret](#input\_allow\_current\_context\_to\_access\_secret) | Allow the current user to access the secret | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the lambda function | `string` | `"Lambda Function that performs some predefined action"` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Handler for the lambda function | `string` | `"lambda_function.lambda_handler"` | no |
| <a name="input_initial_secret_json_value"></a> [initial\_secret\_json\_value](#input\_initial\_secret\_json\_value) | Initial secret value to store in Secrets Manager, provided as a JSON map object, generated by random\_password if not provided | `string` | `""` | no |
| <a name="input_lambda_additional_policy_statements"></a> [lambda\_additional\_policy\_statements](#input\_lambda\_additional\_policy\_statements) | Additional policy statements to add to the lambda function policy, will be merged in | `any` | `{}` | no |
| <a name="input_notification_webhook_secret_id"></a> [notification\_webhook\_secret\_id](#input\_notification\_webhook\_secret\_id) | Secret ID for the webhook URL | `string` | `null` | no |
| <a name="input_notification_webhook_url"></a> [notification\_webhook\_url](#input\_notification\_webhook\_url) | Webhook URL for notifications | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix for resources | `string` | `""` | no |
| <a name="input_recovery_window_in_days"></a> [recovery\_window\_in\_days](#input\_recovery\_window\_in\_days) | The number of days that Secrets Manager waits before it can delete the secret | `number` | `7` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_rotation_rules"></a> [rotation\_rules](#input\_rotation\_rules) | Rotation rules for the secret | `map(any)` | <pre>{<br>  "schedule_expression": "rate(30 days)"<br>}</pre> | no |
| <a name="input_rotation_tag_key"></a> [rotation\_tag\_key](#input\_rotation\_tag\_key) | Tag key to identify resources that need password rotation | `string` | `"Password-Rotation"` | no |
| <a name="input_rotation_tag_value"></a> [rotation\_tag\_value](#input\_rotation\_tag\_value) | Tag value to identify resources that need password rotation | `string` | `"enabled"` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Runtime for the lambda function | `string` | `"python3.9"` | no |
| <a name="input_secrets_manager_additional_policy_statements"></a> [secrets\_manager\_additional\_policy\_statements](#input\_secrets\_manager\_additional\_policy\_statements) | Additional policy statements to add to the Secrets Manager policy, will be merged in | `any` | `{}` | no |
| <a name="input_secrets_manager_secret_description"></a> [secrets\_manager\_secret\_description](#input\_secrets\_manager\_secret\_description) | Description of the secret in Secrets Manager | `string` | `"Rotated Secrets Manager secret"` | no |
| <a name="input_secrets_manager_secret_name"></a> [secrets\_manager\_secret\_name](#input\_secrets\_manager\_secret\_name) | Name of the secret in Secrets Manager | `string` | `null` | no |
| <a name="input_secrets_manager_secret_name_prefix"></a> [secrets\_manager\_secret\_name\_prefix](#input\_secrets\_manager\_secret\_name\_prefix) | Prefix for the secret in Secrets Manager | `string` | `"password-rotation-"` | no |
| <a name="input_suffix"></a> [suffix](#input\_suffix) | Suffix for resources | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Timeout for the lambda function | `number` | `900` | no |
| <a name="input_users"></a> [users](#input\_users) | List of users to change passwords for password lambda function | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_password_function_arn"></a> [lambda\_password\_function\_arn](#output\_lambda\_password\_function\_arn) | Arn for lambda password function |
| <a name="output_secrets_manager_secret_arn"></a> [secrets\_manager\_secret\_arn](#output\_secrets\_manager\_secret\_arn) | Arn for secrets manager secret |
| <a name="output_secrets_manager_secret_id"></a> [secrets\_manager\_secret\_id](#output\_secrets\_manager\_secret\_id) | Version ID for the secrets manager secret |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
