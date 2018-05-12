variable "auth_id" {
  description = "Keypair for instance provisioning"
}

variable "sg_id" {
  description = "Default security group id"
}

variable "vpc_id" {
  description = "VPC to host security group"
}

variable "subnet_id" {
  description = "LB subnet id"
}

variable "name_prefix" {}

resource "aws_iam_role" "wp-lab" {
  name        = "wp-lab"
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

resource "aws_iam_role_policy" "wp-lab_allow_s3" {
  name = "wp-lab_allow_s3"
  role = "${aws_iam_role.wp-lab.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
          "s3:Get*",
          "s3:List*"
        ],
        "Resource": [ "*" ]
    }
  ]
}
EOF
}

### Instace should be allowed to access s3 with deployments scripts.
resource "aws_iam_instance_profile" "wp-lab" {
  name = "wp-lab"
  role = "${aws_iam_role.wp-lab.name}"
}

resource "aws_launch_configuration" "this" {
  name_prefix          = "${var.name_prefix}"
  image_id             = "ami-d2fa88ae"
  instance_type        = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.wp-lab.id}"
  security_groups      = ["${var.sg_id}"]
  key_name             = "${var.auth_id}"
  user_data            = "${file("modules/front/userdata.sh")}"

  root_block_device {
    volume_size           = "8"
    delete_on_termination = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}"
  description = "! Managed by terraform"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "this" {
  name = "${var.name_prefix}"

  subnets         = ["${var.subnet_id}"]
  security_groups = ["${aws_security_group.this.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 2
    target              = "HTTP:80/"
    interval            = 5
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.name_prefix}"
  launch_configuration      = "${aws_launch_configuration.this.name}"
  availability_zones        = ["ap-southeast-1a"]
  vpc_zone_identifier       = ["${var.subnet_id}"]
  min_size                  = 1
  max_size                  = 3
  enabled_metrics           = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
  metrics_granularity       = "1Minute"
  load_balancers            = ["${aws_elb.this.id}"]
  health_check_grace_period = 240
  health_check_type         = "ELB"

  tag {
    key                 = "Name"
    value               = "asg-${var.name_prefix}"
    propagate_at_launch = true
  }
}

resource "aws_cloudwatch_metric_alarm" "this" {
  alarm_name          = "${var.name_prefix}-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "60"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.this.name}"
  }

  alarm_description = "This metric monitor EC2 instance cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.scale_out.arn}"]
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.name_prefix}-scale_out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.this.name}"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.name_prefix}-scale_up"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120
  autoscaling_group_name = "${aws_autoscaling_group.this.name}"
}

resource "aws_cloudwatch_metric_alarm" "cpualarm-down" {
  alarm_name          = "${var.name_prefix}-alarm-down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "10"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.this.name}"
  }

  alarm_description = "This metric monitor EC2 instance cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.scale_down.arn}"]
}

output "asg_name" {
  value = "${aws_autoscaling_group.this.name}"
}

output "elb_dns_name" {
  value = "${aws_elb.this.dns_name}"
}

output "elb_name" {
  value = "${aws_elb.this.name}"
}
