###########################################################
################## Global Settings ########################

tags = {
  Environment = "dev"
  Project     = "du-iac-cicd"
}
prefix = "ex-complete"

###########################################################
################## Bastion Config #########################

bastion_ssh_user = "ec2-user" # local user in bastion used to ssh
# renovate: datasource=github-tags depName=defenseunicorns/zarf
zarf_version = "v0.33.0"

######################################################
################## Lambda Config #####################

################# Password Rotation ##################
# Add users that will be on your ec2 instances.
users = ["ec2-user"]
