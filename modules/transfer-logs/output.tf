output "lambda_transfer_function_arn" {
  description = "Arn for lambda transfer function"
  value       = module.transfer_lambda.lambda_function_arn
}
