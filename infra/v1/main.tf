terraform {
  required_version  = ">= 0.10.8"

  variable "s3_bucket" {}
  variable "tfstate_key" {}

  # backend fix
  backend "s3" {
    # bucket = "${var.s3_bucket}"
    # key    = "${var.tfstate_key}"
    # region = "${var.region}"
}
}

variable "access_key" {}
variable "secret_key" {}

variable "region" {
    default = "us-east-1"
}

variable "env" {}
variable "consul_ami" {}
variable "ssh_keypair" {}

variable "azs" {
    default = "us-east-1a,us-east-1b,us-east-1c,us-east-1e"
}

provider "aws" {
    version = "~> 1.9"
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "${var.region}"
}

# The next resources define a new vpc with a public subnet for every
# availabilty zone and a default security group completely open. This isn't
# meant to be used in a production environment, it's just to make the vpc
# definition the most concise as possible.

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags {
        Name = "vpc ${var.env} ${var.region}"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = "${aws_vpc.vpc.id}"

    tags {
        Name = "igw ${var.env} ${var.region}"
    }
}

# Create a subnet for every availability zone
resource "aws_subnet" "front" {
    count = "${length(split(",", var.azs))}"
    vpc_id = "${aws_vpc.vpc.id}"
    cidr_block = "10.0.${count.index * 16}.0/20"
    map_public_ip_on_launch = true
    availability_zone = "${element(split(",", var.azs), count.index)}"

    tags {
        Name = "subnet ${count.index} ${element(split(",", var.azs), count.index)}"
    }
}

resource "aws_route_table" "public" {
    vpc_id = "${aws_vpc.vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.igw.id}"
    }

    tags {
        Name = "${var.region} ${var.env} public"
    }
}

resource "aws_route_table_association" "front" {
    count = "${length(split(",", var.azs))}"
    subnet_id = "${element(aws_subnet.front.*.id, count.index)}"
    route_table_id = "${aws_route_table.public.id}"
}

# An (in)security_group :D
resource "aws_security_group" "allow_all" {
    name = "allow_all"
    description = "Allow all inbound traffic"

    vpc_id = "${aws_vpc.vpc.id}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Here we define out instances, volumes etc.
# Some notes:
# * Do not use an unique resource with a count, since we want to distribute
# them on different availability zones
# * We have to avoid an hard dependency between the ebs and the instances since
# it will make terraform recreate the ebs when an instance is recreated.

resource "aws_volume_attachment" "consul_server01_ebs_attachment" {
  device_name = "/dev/xvdb"
  volume_id = "${aws_ebs_volume.consul_server01_ebs.id}"
  instance_id = "${aws_instance.consul_server01.id}"
}

resource "aws_ebs_volume" "consul_server01_ebs" {
  availability_zone = "us-east-1a"
  size = 1
}

resource "aws_volume_attachment" "consul_server02_ebs_attachment" {
  device_name = "/dev/xvdb"
  volume_id = "${aws_ebs_volume.consul_server02_ebs.id}"
  instance_id = "${aws_instance.consul_server02.id}"
}

resource "aws_ebs_volume" "consul_server02_ebs" {
  availability_zone = "us-east-1b"
  size = 1
}

resource "aws_volume_attachment" "consul_server03_ebs_attachment" {
  device_name = "/dev/xvdb"
  volume_id = "${aws_ebs_volume.consul_server03_ebs.id}"
  instance_id = "${aws_instance.consul_server03.id}"
}

resource "aws_ebs_volume" "consul_server03_ebs" {
  availability_zone = "us-east-1c"
  size = 1
}


# Use a fixed ip address for various reasons:
# * Avoid consul raft logic problems with changing ips when instance is
# recreated (https://github.com/hashicorp/consul/issues/457). Another solution
# will be to let consul server leave the raft cluster but this will make a
# temporary 2 node cluster and, if another node fails, it will lose the quorum
# requiring a manual operation to restore it in a working state.
resource "aws_instance" "consul_server01" {
    ami = "${var.consul_ami}"
    instance_type = "t2.micro"
    iam_instance_profile = "ec2-role"
    key_name = "${var.ssh_keypair}"
    subnet_id = "${aws_subnet.front.0.id}"
    vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
    private_ip = "${cidrhost(aws_subnet.front.0.cidr_block, 10)}"
    tags = {
        "consul-type" = "server"
    }
}

resource "aws_instance" "consul_server02" {
    ami = "${var.consul_ami}"
    instance_type = "t2.micro"
    iam_instance_profile = "ec2-role"
    key_name = "${var.ssh_keypair}"
    subnet_id = "${aws_subnet.front.1.id}"
    vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
    private_ip = "${cidrhost(aws_subnet.front.1.cidr_block, 10)}"
    tags = {
        "consul-type" = "server"
    }
}

resource "aws_instance" "consul_server03" {
    ami = "${var.consul_ami}"
    instance_type = "t2.micro"
    iam_instance_profile = "ec2-role"
    key_name = "${var.ssh_keypair}"
    subnet_id = "${aws_subnet.front.2.id}"
    vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
    private_ip = "${cidrhost(aws_subnet.front.2.cidr_block, 10)}"
    tags = {
        "consul-type" = "server"
    }
}

### Outputs ###

output region {
	value = "${var.region}"
}

output vpc_id {
    value = "${aws_vpc.vpc.id}"
}

output security_group_allow_all_id {
    value = "${aws_security_group.allow_all.id}"
}

output subnets {
    value = "${join(",", aws_subnet.front.*.id)}"
}

# output "instance_ids" {
#   value = ["${aws_instance.consul_server03.primary.id}"]
# }
