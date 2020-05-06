################################################################################
# VPC

resource aws_vpc main {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.tag_prefix}-vpc"
  }
}

output vpc_id {
  value = aws_vpc.main.id
}

################################################################################
# Subnet

resource aws_subnet back_a {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 8, 100)
  availability_zone = var.availability_zone_a
  tags = {
    Name = "${var.tag_prefix}-back_a"
  }
}

################################################################################
# Security Group

resource aws_security_group sg {
  vpc_id      = aws_vpc.main.id
  name        = "${var.tag_prefix}-sg"
  description = "${var.tag_prefix}-sg"

  tags = {
    Name = "${var.tag_prefix}-sg"
  }

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    self      = true
  }

  ingress {
    protocol    = "icmp"
    from_port   = -1
    to_port     = -1
    cidr_blocks = [var.vpc_peer_cidr_block]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 587
    to_port     = 587
    cidr_blocks = [var.vpc_peer_cidr_block]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
