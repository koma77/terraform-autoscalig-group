variable "auth_id" {
  description = "Keypair for instance provisioning"
}

variable "vpc_id" {
}

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

resource "aws_instance" "jenkins" {
  connection {
    user        = "centos"
    private_key = "${file("~/.ssh/tf")}"
  }

  instance_type = "t2.micro"
  ami           = "ami-d2fa88ae"
  key_name      = "${var.auth_id}"

  vpc_security_group_ids = ["${aws_security_group.jenkins.id}"]
  subnet_id              = "${var.subnet_id}"

  root_block_device {
    volume_size           = "8"
    delete_on_termination = "true"
  }

  tags {
    Name = "Jenkins 2.107 on 8080"
  }
}

### Need this to break dependancy cycle between elb and instance
resource "null_resource" "ansible-provisioner" {
  provisioner "local-exec" {
    command = "while ! nc -z ${aws_instance.jenkins.public_ip} 22; do sleep 1; done ; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u centos --private-key ~/.ssh/tf -i ${aws_instance.jenkins.public_ip},  ansible/jenkins.yml"
  }
}

output "jenkins_int_ip" {
  value = "${aws_instance.jenkins.private_ip}"
}

output "jenkins_ip" {
  value = "${aws_instance.jenkins.public_ip}"
}
