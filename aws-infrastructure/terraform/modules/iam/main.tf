data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gitlab_runner" {
  name               = "${var.prefix}${var.suffix}-gitlab-runner"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = merge(local.tags, { Name = "${var.prefix}${var.suffix}-gitlab-runner" })
  inline_policy {
    name   = "${var.prefix}${var.suffix}-gitlab-runner-permissions"
    policy = file("${path.module}/policies/gitlab_runner.json")
  }
}

resource "aws_iam_instance_profile" "gitlab_runner" {
  name = "${var.prefix}${var.suffix}-gitlab-runner"
  role = aws_iam_role.gitlab_runner.name
  tags = merge(local.tags, { Name = "${var.prefix}${var.suffix}-gitlab-runner" })
}
