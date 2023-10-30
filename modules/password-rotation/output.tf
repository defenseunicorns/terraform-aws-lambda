output "lambda_password_function_arn" {
  description = "Arn for lambda password function"
  value       = module.password_lambda.lambda_function_arn
}
