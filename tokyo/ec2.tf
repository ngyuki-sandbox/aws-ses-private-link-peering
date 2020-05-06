################################################################################
# EC2

resource aws_instance server {
  ami                         = var.ami_id
  key_name                    = var.key_name
  instance_type               = "t3.nano"
  subnet_id                   = aws_subnet.back_a.id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  iam_instance_profile        = var.instance_profile
  ebs_optimized               = false
  monitoring                  = false
  associate_public_ip_address = false

  user_data = <<-EOS
    #cloud-config
    timezone: "Asia/Tokyo"
    hostname: "${var.tag_prefix}-server"
    write_files:
      - path: "/etc/environment"
        content: |
          SMTP_USERNAME=${var.smtp_username}
          SMTP_PASSWORD=${var.smtp_password}
          SMTP_HOSTNAME=${var.smtp_hostname}
    EOS

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }

  tags = {
    Name = "${var.tag_prefix}-server"
  }

  depends_on = [
    # SSM の VPC endpoint よりも先に開始すると SSM Session Manager で SSH できない
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssmmessages,
  ]
}

output "instances" {
  value = {
    server = {
      instance_id = aws_instance.server.id
      private_ip  = aws_instance.server.private_ip
    }
  }
}
