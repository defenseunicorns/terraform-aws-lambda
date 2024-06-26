variable "prefix" {
  description = "Name prefix"
  type        = string
  validation {
    condition     = length(var.prefix) <= 37
    error_message = "Name Prefix may not be longer than 37 characters."
  }
}

variable "region" {
  description = "The AWS region to deploy into"
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "iam_role_permissions_boundary" {
  description = "ARN of the policy that is used to set the permissions boundary for IAM roles"
  type        = string
  default     = null
}

###########################################################
################## Bastion Config #########################
variable "bastion_tenancy" {
  description = "The tenancy of the bastion"
  type        = string
  default     = "default"
}

variable "bastion_instance_type" {
  description = "value for the instance type of the EKS worker nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "bastion_ssh_user" {
  description = "The SSH user to use for the bastion"
  type        = string
  default     = "ec2-user"
}

variable "zarf_version" {
  description = "The version of Zarf to use"
  type        = string
  default     = ""
}

variable "kms_key_deletion_window" {
  description = "Waiting period for scheduled KMS Key deletion. Can be 7-30 days."
  type        = number
  default     = 7
}

variable "access_log_expire_days" {
  description = "Number of days to wait before deleting access logs"
  type        = number
  default     = 30
}

variable "enable_sqs_events_on_access_log_access" {
  description = "If true, generates an SQS event whenever on object is created in the Access Log bucket, which happens whenever a server access log is generated by any entity. This will potentially generate a lot of events, so use with caution."
  type        = bool
  default     = false
}

variable "private_ip" {
  description = "The private IP address to assign to the bastion"
  type        = string
  default     = ""
}

############################################################################
################## Lambda Password Rotation Config #########################

variable "users" {
  description = "This needs to be a list of users that will be on your ec2 instances that need password changes."
  type        = list(string)
  default     = []
}

variable "notification_webhook_url" {
  description = "Webhook URL for notifications from Lambda function"
  type        = string
  default     = null
}
