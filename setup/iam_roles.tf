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
resource "aws_iam_role" "instance_aws_access_role" {
    name = "instance_aws_access"
    path = "/"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ec2_describe_policy" {
    name = "ec2_describe"
    role = "${aws_iam_role.instance_aws_access_role.id}"
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

resource "aws_iam_instance_profile" "default_instance_profile" {
    name = "default_instance_profile"
    roles = ["${aws_iam_role.instance_aws_access_role.name}"]
}


