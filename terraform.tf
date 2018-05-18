provider "aws" {
  region                  = "ap-southeast-1"
  shared_credentials_file = "~/.aws/tf_lab"
}

resource "aws_vpc" "lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
}

resource "aws_route53_zone" "local" {
  name   = "local"
  vpc_id = "${aws_vpc.lab_vpc.id}"
}

resource "aws_route53_record" "registry" {
  zone_id = "${aws_route53_zone.local.zone_id}"
  name    = "registry.local"
  type    = "A"
  ttl     = "300"
  records = ["${module.jenkins.jenkins_int_ip}"]
}

resource "aws_route53_record" "lab-db" {
  zone_id = "${aws_route53_zone.local.zone_id}"
  name    = "lab-db.local"
  type    = "CNAME"
  ttl     = "300"
  records = ["${module.db.rds_addr}"]
}

resource "aws_internet_gateway" "lab_gw" {
  vpc_id = "${aws_vpc.lab_vpc.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.lab_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.lab_gw.id}"
}

resource "aws_subnet" "lab" {
  availability_zone       = "ap-southeast-1a"
  vpc_id                  = "${aws_vpc.lab_vpc.id}"
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "lab_1b" {
  availability_zone       = "ap-southeast-1b"
  vpc_id                  = "${aws_vpc.lab_vpc.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "default" {
  name        = "sec_group_default"
  description = "! Managed by terraform"
  vpc_id      = "${aws_vpc.lab_vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # ICMP
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "terraform"
  public_key = "${file("~/.ssh/tf.pub")}"
}

module "jenkins" {
  source    = "modules/jenkins"
  auth_id   = "${aws_key_pair.auth.id}"
  vpc_id    = "${aws_vpc.lab_vpc.id}"
  subnet_id = "${aws_subnet.lab.id}"
}

variable "dba_passwd" {}

module "db" {
  source     = "modules/db"
  subnet1_id = "${aws_subnet.lab.id}"
  subnet2_id = "${aws_subnet.lab_1b.id}"
  vpc_id     = "${aws_vpc.lab_vpc.id}"
  dba_passwd = "${var.dba_passwd}"
}

module "front1" {
  source      = "modules/front"
  auth_id     = "${aws_key_pair.auth.id}"
  sg_id       = "${aws_security_group.default.id}"
  vpc_id      = "${aws_vpc.lab_vpc.id}"
  subnet_id   = "${aws_subnet.lab.id}"
  name_prefix = "front1"
}

### INPLACE DEPLOY ###
#module "codedeploy" {
#  source   = "modules/codedeploy"
#  elb_name = "${module.front1.elb_name}"
#  asg_name = "${module.front1.asg_name}"
#}

#module "lambda" {
#  source        = "modules/lambda"
#  sns_topic_arn = "${module.codedeploy.sns_topic_arn}"
#}

### BG DEPLOY ###
module "codedeploy_bg" {
  source   = "modules/codedeploy_bg"
  elb_name = "${module.front1.elb_name}"
  asg_name = "${module.front1.asg_name}"
}

module "lambda" {
  source        = "modules/lambda"
  sns_topic_arn = "${module.codedeploy_bg.sns_topic_arn}"
}

output "rds_endpoint" {
  value = "${module.db.rds_addr}"
}

output "dba_passwd" {
  value = "${var.dba_passwd }"
}

output "elb-lab1" {
  value = "${module.front1.elb_dns_name}"
}

#output "elb-lab2" {
#  value = "${module.front2.lb_dns_name}"
#}

output "jenkins_ip" {
  value = "${module.jenkins.jenkins_ip}"
}
