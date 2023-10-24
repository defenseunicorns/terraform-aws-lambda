###########################################################
################## Global Settings ########################

tags = {
  Environment = "dev"
  Project     = "du-iac-cicd"
}
name_prefix               = "ex-complete"
manage_aws_auth_configmap = true

###########################################################
#################### VPC Config ###########################

vpc_cidr              = "10.200.0.0/16"
secondary_cidr_blocks = ["100.64.0.0/16"] #https://aws.amazon.com/blogs/containers/optimize-ip-addresses-usage-by-pods-in-your-amazon-eks-cluster/

###########################################################
################## Bastion Config #########################

bastion_ssh_user     = "ec2-user" # local user in bastion used to ssh
bastion_ssh_password = "my-password"
# renovate: datasource=github-tags depName=defenseunicorns/zarf
zarf_version = "v0.29.2"

######################################################
################## Lambda Config #####################

################# Password Rotation ##################
enable_password_rotation_lambda = true
# Add users that will be on your ec2 instances.
users = ["ec2-user", "Administrator"]

cron_schedule_password_rotation = "cron(0 0 1 * ? *)"

slack_notification_enabled = false

slack_webhook_url = ""