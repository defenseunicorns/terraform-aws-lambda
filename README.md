# AWS Lambda Module

This repository contains Lambda modules that are deployed using Terraform.

## Usage

If you want to create new functionality, you can do so by writing your lambda code and storing it in its own directory. For example, the code for the password rotation function can be stored in the directory `fixtures/functions/password-rotation/lambda_function.py`. In your `main.tf` file, use the following `source_path`:

`source_path = "${path.module}/fixtures/functions/password-rotation/lambda_function.py"`

### Lambda Password Module

This module deploys a Python function that securely generates and rotates EC2 instance passwords for EC2 Linux instances using AWS Systems Manager (SSM), Secrets Manager, and Lambda. The function is triggered by the [builtin Secrets Manager secret rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html) process

#### Example

To see an example of how to leverage this Lambda Module, please refer to the [examples](https://github.com/defenseunicorns/delivery-aws-iac/tree/main/examples) directory.
