################################################################################
# instance profile ec2

resource aws_iam_role ec2 {
  name               = "${var.tag_prefix}-ec2"
  assume_role_policy = <<-POLICY
    {
        "Version": "2012-10-17",
        "Statement": [
            {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
            }
        ]
    }
    POLICY
}

resource aws_iam_instance_profile ec2 {
  name = "${var.tag_prefix}-ec2"
  role = aws_iam_role.ec2.name
}

data aws_iam_policy ec2 {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource aws_iam_role_policy_attachment ec2 {
  role       = aws_iam_role.ec2.name
  policy_arn = data.aws_iam_policy.ec2.arn
}

output instance_profile {
  value = aws_iam_role.ec2.id
}

################################################################################
# iam user smtp

resource aws_iam_user smtp {
  name = "${var.tag_prefix}-smtp"
}

resource aws_iam_user_policy smtp {
  name   = "smtp"
  user   = aws_iam_user.smtp.name
  policy = <<-POLICY
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "ses:SendRawEmail",
                "Resource": "*"
            }
        ]
    }
    POLICY
}

resource aws_iam_access_key smtp {
  user = aws_iam_user.smtp.name
}

output smtp_access_key {
  value = {
    id                = aws_iam_access_key.smtp.id
    ses_smtp_password = aws_iam_access_key.smtp.ses_smtp_password
  }
}
