variable "auth_id" {
  description = "Keypair for instance provisioning"
}

variable "sg_id" {
  description = "Default security group id"
}

variable "subnet_id" {
  description = "VM subnet id"
}

resource "aws_instance" "jenkins" {
  connection {
    user        = "centos"
    private_key = "${file("~/.ssh/tf")}"
  }

  instance_type = "t2.micro"
  ami           = "ami-d2fa88ae"
  key_name      = "${var.auth_id}"

  vpc_security_group_ids = ["${var.sg_id}"]
  subnet_id              = "${var.subnet_id}"

  root_block_device {
    volume_size           = "8"
    delete_on_termination = "true"
  }
}

### Need this to break dependancy cycle between elb and instance
resource "null_resource" "ansible-provisioner" {
  provisioner "local-exec" {
    command = "sleep 10; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u centos --private-key ~/.ssh/tf -i ${aws_instance.jenkins.public_ip},  ansible/jenkins.yml"
  }
}

output "jenkins_int_ip" {
  value = "${aws_instance.jenkins.private_ip}"
}

output "jenkins_ip" {
  value = "${aws_instance.jenkins.public_ip}"
}
