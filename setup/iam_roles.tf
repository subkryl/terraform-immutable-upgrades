variable "access_key" {}
variable "secret_key" {}

variable "region" {
    default = "us-east-1"
}

provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

# Define an iam instance profile needed for executing the aws cli inside the
# instances without expliciting providing and access and a secret key
resource "aws_iam_role" "ec2-role" {
    name = "ec2-role"
    # path = "/"
    assume_role_policy = <<EOF
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
EOF
}


resource "aws_iam_instance_profile" "ec2-role" {
    name = "ec2-role"
    role = "${aws_iam_role.ec2-role.name}"
}

resource "aws_iam_role_policy" "ec2-role-policy" {
    name = "ec2-role-policy"
    role = "${aws_iam_role.ec2-role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
