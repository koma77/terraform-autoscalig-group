variable "sns_topic_arn" {}

resource "aws_iam_role" "lab_lambda" {
  name = "lab_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lab_lambda" {
  name = "iam_for_lambda"
  role = "${aws_iam_role.lab_lambda.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "codedeploy:*",
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

#The filename.handler-method value in your function. For example,
# "main.handler" would call the handler method defined in main.py.
# file_name.handler_func
resource "aws_lambda_function" "update_deployment_artifacts" {
  filename         = "modules/lambda/update_deployment_artifacts.zip"
  function_name    = "update_deployment_artifacts"
  role             = "${aws_iam_role.lab_lambda.arn}"
  handler          = "update_deployment_artifacts.lambda_handler"
  source_code_hash = "${base64sha256(file("modules/lambda/update_deployment_artifacts.zip"))}"
  runtime          = "python3.6"
}

resource "aws_sns_topic_subscription" "update_deployment_artifacts" {
  depends_on = ["aws_lambda_function.update_deployment_artifacts"]
  topic_arn  = "${var.sns_topic_arn}"
  protocol   = "lambda"
  endpoint   = "${aws_lambda_function.update_deployment_artifacts.arn}"
}

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.update_deployment_artifacts.arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${var.sns_topic_arn}"
}
