# db module
variable "subnet1_id" {
  description = "First availability zone subnet id"
}

variable "subnet2_id" {
  description = "Second availability zone subnet id"
}

variable "vpc_id" {
  description = "VPC id to host a security group"
}

variable "dba_passwd" {}

resource "aws_db_subnet_group" "db-subnet" {
  name        = "lab-db-subnet"
  description = "! Managed by terraform"
  subnet_ids  = ["${var.subnet1_id}", "${var.subnet2_id}"]
}

resource "aws_db_parameter_group" "default" {
  name   = "rs-pg"
  family = "mysql5.6"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}

resource "aws_security_group" "db" {
  name        = "sec_group_db"
  description = "! Managed by terraform"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "db" {
  identifier             = "lab-db-mysql56"
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.6"
  instance_class         = "db.t2.micro"
  name                   = "mydb"
  username               = "dba"
  password               = "${var.dba_passwd}"
  publicly_accessible    = false
  multi_az               = false
  parameter_group_name   = "rs-pg"
  skip_final_snapshot    = true
  db_subnet_group_name   = "${aws_db_subnet_group.db-subnet.name}"
  vpc_security_group_ids = ["${aws_security_group.db.id}"]
}

output "rds_addr" {
  value = "${aws_db_instance.db.address}"
}
