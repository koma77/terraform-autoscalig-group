variable "auth_id" {
  description = "Keypair for instance provisioning"
}

variable "vpc_id" {}

variable "subnet_id" {
  description = "VM subnet id"
}

resource "aws_security_group" "jenkins" {
  name        = "sec_group_jenkins"
  description = "! Managed by terraform"
  vpc_id      = "${var.vpc_id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Docker registry
  ingress {
    from_port   = 5000
    to_port     = 5000
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

resource "aws_iam_role" "deploy-lab" {
  name        = "deploy-lab"
  description = "!Managed by terrafrom"

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

resource "aws_iam_role_policy" "deploy-lab_allow_s3_codedeploy" {
  name = "deploy-lab_allow_s3_codedeploy"
  role = "${aws_iam_role.deploy-lab.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
          "s3:*",
          "codedeploy:*"
        ],
        "Resource": [ "*" ]
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "deploy-lab" {
  name = "deploy-lab"
  role = "${aws_iam_role.deploy-lab.name}"
}

resource "aws_instance" "jenkins" {
  connection {
    user        = "centos"
    private_key = "${file("~/.ssh/tf")}"
  }

  instance_type        = "t2.micro"
  ami                  = "ami-da6151a6"
  key_name             = "${var.auth_id}"
  iam_instance_profile = "${aws_iam_instance_profile.deploy-lab.id}"

  vpc_security_group_ids = ["${aws_security_group.jenkins.id}"]
  subnet_id              = "${var.subnet_id}"

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u centos --private-key ~/.ssh/tf -i ${aws_instance.jenkins.public_ip},  ansible/jenkins.yml"
  }

  root_block_device {
    volume_size           = "8"
    delete_on_termination = "true"
  }

  tags {
    Name = "Jenkins 2.107 on 8080"
  }
}

resource "aws_s3_bucket" "deploy-lab" {
  bucket = "deploy-lab"
  acl    = "private"

  tags {
    Name = "Deployment bucket"
  }
}

resource "aws_s3_bucket" "wp-db-bck" {
  bucket = "wp-db-bck"
  acl    = "private"

  tags {
    Name = "DB backups bucket"
  }
}

### Need this to break dependancy cycle between elb and instance
#resource "null_resource" "ansible-provisioner" {
#  provisioner "local-exec" {
#    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u centos --private-key ~/.ssh/tf -i ${aws_instance.jenkins.public_ip},  ansible/jenkins.yml"
#  }
#}

output "jenkins_int_ip" {
  value = "${aws_instance.jenkins.private_ip}"
}

output "jenkins_ip" {
  value = "${aws_instance.jenkins.public_ip}"
}
