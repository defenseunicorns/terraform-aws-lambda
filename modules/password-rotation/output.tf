output "lambda_password_function_arn" {
  description = "Arn for lambda password function"
  value       = module.password_lambda.lambda_function_arn
}

output "secrets_manager_secret_arn" {
  description = "Arn for secrets manager secret"
  value       = module.secrets_manager.secret_arn
}

output "secrets_manager_secret_id" {
  description = "Version ID for the secrets manager secret"
  value       = module.secrets_manager.secret_id
}
