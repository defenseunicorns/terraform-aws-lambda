output "bastion_instance_id" {
  description = "The ID of the bastion host"
  value       = try(module.bastion.instance_id, null)
  sensitive   = true
}

output "bastion_region" {
  description = "The region that the bastion host was deployed to"
  value       = try(module.bastion.region, null)
  sensitive   = true
}

output "bastion_private_dns" {
  description = "The private DNS address of the bastion host"
  value       = try(module.bastion.private_dns, null)
  sensitive   = true
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
  sensitive   = true
}

output "lambda_password_function_arn" {
  description = "Arn for lambda password function"
  value       = try(module.password_lambda.lambda_password_function_arn, null)
}
