data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "default" {
  name               = "${local.common_tags.Name}-dlm-lifecycle-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "dlm" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSnapshot",
      "ec2:CreateSnapshots",
      "ec2:DeleteSnapshot",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
    ]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*::snapshot/*"]
  }
}

resource "aws_iam_role_policy" "default" {
  name   = "${local.common_tags.Name}-dlm-lifecycle-policy"
  role   = aws_iam_role.default.id
  policy = data.aws_iam_policy_document.dlm.json
}

resource "aws_dlm_lifecycle_policy" "default" {
  description        = "${local.common_tags.Name}-dlm-policy"
  execution_role_arn = aws_iam_role.default.arn
  state              = "ENABLED"
  policy_details {
    resource_types = ["INSTANCE"]
    schedule {
      name = "${local.common_tags.Name}-dlm-schedule"
      create_rule {
        interval      = var.schedule.interval
        interval_unit = var.schedule.interval_unit
        times         = var.schedule.times
      }
      retain_rule {
        count = var.retain_count
      }
      tags_to_add = {
        SnapshotCreator = "DLM"
      }
      copy_tags = true
    }
    target_tags = var.target_tags
  }
  tags = merge(local.tags, { Name = "${local.common_tags.Name}-dlm-policy" })
}
