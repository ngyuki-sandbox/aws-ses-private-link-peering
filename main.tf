module common {
  source     = "./common"
  tag_prefix = "ses-private-link-peering-common"
}

variable key_name {}

module oregon {
  source               = "./oregon"
  tag_prefix           = "ses-private-link-peering-oregon"
  region               = "us-west-2"
  availability_zone_a  = "us-west-2a"
  vpc_cidr_block       = "10.200.0.0/16"
  vpc_peer_region      = "ap-northeast-1"
  vpc_peer_vpc_id      = module.tokyo.vpc_id
  vpc_peer_cidr_block  = "10.100.0.0/16"
  vpc_peer_accepter_id = module.tokyo.vpc_peering_accepter_id
  ami_id               = "ami-0d6621c01e8c2de2c" # Amazon Linux 2 AMI 2.0.20200304.0 x86_64 HVM gp2
  key_name             = var.key_name
  instance_profile     = module.common.instance_profile
  smtp_hostname        = "email-smtp.us-west-2.amazonaws.com"
  smtp_username        = module.common.smtp_access_key.id
  smtp_password        = module.common.smtp_access_key.ses_smtp_password
}

module tokyo {
  source                = "./tokyo"
  tag_prefix            = "ses-private-link-peering-tokyo"
  region                = "ap-northeast-1"
  availability_zone_a   = "ap-northeast-1a"
  vpc_cidr_block        = "10.100.0.0/16"
  vpc_peer_cidr_block   = "10.200.0.0/16"
  vpc_peer_requester_id = module.oregon.vpc_peering_requester_id
  ami_id                = "ami-0f310fced6141e627" # Amazon Linux 2 AMI 2.0.20200304.0 x86_64 HVM gp2
  key_name              = var.key_name
  instance_profile      = module.common.instance_profile
  smtp_hostname         = module.oregon.vpc_endpoint_smtp_dns_name
  smtp_username         = module.common.smtp_access_key.id
  smtp_password         = module.common.smtp_access_key.ses_smtp_password
}

output "instances" {
  value = {
    oregon = module.oregon.instances
    tokyo  = module.tokyo.instances
  }
}
