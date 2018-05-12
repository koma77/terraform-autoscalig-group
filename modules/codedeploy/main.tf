variable "asg_name" {}

variable "elb_name" {}

resource "aws_iam_role" "lab-codedeploy" {
  name = "lab-codedeploy"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lab-codedeploy" {
  name = "lab-codedeploy"
  role = "${aws_iam_role.lab-codedeploy.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:DeleteLifecycleHook",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLifecycleHooks",
        "autoscaling:PutLifecycleHook",
        "autoscaling:RecordLifecycleActionHeartbeat",
        "codedeploy:*",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "tag:GetTags",
        "tag:GetResources",
        "sns:Publish",
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_codedeploy_app" "WP_APP" {
  name = "WP_APP"
}

resource "aws_codedeploy_deployment_group" "LAB-WP" {
  app_name              = "${aws_codedeploy_app.WP_APP.name}"
  deployment_group_name = "LAB_WP"
  service_role_arn      = "${aws_iam_role.lab-codedeploy.arn}"
  autoscaling_groups    = ["${var.asg_name}"]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info {
    elb_info {
      name = "${var.elb_name}"
    }
  }

  trigger_configuration {
    trigger_events     = ["DeploymentSuccess"]
    trigger_name       = "update_successful_deployment"
    trigger_target_arn = "${aws_sns_topic.lab_wp_codedeploy.arn}"
  }
}

resource "aws_sns_topic" "lab_wp_codedeploy" {
  name = "lab_wp_codedeploy"
}

output "sns_topic_arn" {
  value = "${aws_sns_topic.lab_wp_codedeploy.arn}"
}
