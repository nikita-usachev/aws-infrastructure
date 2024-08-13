terraform {
  required_providers {
    ansible = {
      source  = "nbering/ansible"
      version = "1.0.4"
    }
  }
}

# data

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id != null ? false : true
}

data "aws_ami" "selected" {
  owners = [var.instance_ami_owner]
  filter {
    name   = "name"
    values = [var.instance_ami_pattern]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  most_recent = true
}

# elastic ip

resource "aws_eip" "ip" {
  count    = var.elastic_ip_enable ? var.instance_count : 0
  instance = var.spot_price == null ? aws_instance.vms[count.index].id : aws_spot_instance_request.vms[count.index].spot_instance_id
  domain   = "vpc"
}

# data disk

resource "aws_ebs_volume" "data" {
  count             = var.data_disk_enable ? var.instance_count : 0
  availability_zone = element(var.avail_zones, count.index)
  size              = var.data_disk_size
  type              = var.data_disk_type

  tags = merge(local.tags, { Name = "${local.common_tags.Name}-${count.index + var.start_index}-data" })
}

resource "aws_volume_attachment" "data" {
  count       = var.data_disk_enable ? var.instance_count : 0
  volume_id   = aws_ebs_volume.data[count.index].id
  instance_id = var.spot_price == null ? aws_instance.vms[count.index].id : aws_spot_instance_request.vms[count.index].id
  device_name = "/dev/sdh"
}

# security group

resource "aws_security_group" "vms" {
  count       = var.instance_count > 0 ? 1 : 0
  vpc_id      = data.aws_vpc.selected.id
  name        = "${local.common_tags.Name}-sg"
  description = "Allow traffic to ${local.common_tags.Name} nodes"
  tags        = merge(local.tags, { Name = "${local.common_tags.Name}-sg" })
}

resource "aws_security_group_rule" "external_cidrs" {
  count             = var.instance_count > 0 && length(var.external_ip_list) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = var.external_ip_list
  security_group_id = aws_security_group.vms[0].id
}

resource "aws_security_group_rule" "external_ports" {
  count             = var.instance_count > 0 ? length(var.external_port_list) : 0
  type              = "ingress"
  from_port         = var.external_port_list[count.index]
  to_port           = var.external_port_list[count.index]
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vms[0].id
}

resource "aws_security_group_rule" "external_security_groups" {
  count                    = var.instance_count > 0 ? length(var.external_sg_list) : 0
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = var.external_sg_list[count.index]
  security_group_id        = aws_security_group.vms[0].id
}

resource "aws_security_group_rule" "local" {
  count             = var.instance_count > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  security_group_id = aws_security_group.vms[0].id
}

resource "aws_security_group_rule" "outgoing" {
  count             = var.instance_count > 0 ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vms[0].id
}

# iam

data "aws_iam_policy_document" "vms" {
  count = var.instance_count > 0 ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vms" {
  count              = var.instance_count > 0 ? 1 : 0
  name               = "${local.common_tags.Name}-role"
  assume_role_policy = data.aws_iam_policy_document.vms[0].json
  dynamic "inline_policy" {
    for_each = var.iam_role_inline_policy != null ? [1] : []
    content {
      name   = "${local.common_tags.Name}-additional-policy"
      policy = var.iam_role_inline_policy
    }
  }
}

resource "aws_iam_role_policy_attachment" "vms" {
  count      = var.instance_count > 0 ? length(var.iam_role_policies) : 0
  role       = aws_iam_role.vms[0].name
  policy_arn = var.iam_role_policies[count.index]
}

resource "aws_iam_instance_profile" "vms" {
  count = var.instance_count > 0 ? 1 : 0
  name  = "${local.common_tags.Name}-profile"
  role  = aws_iam_role.vms[0].name
}

# instances

resource "aws_instance" "vms" {
  count             = var.spot_price == null ? var.instance_count : 0
  ami               = data.aws_ami.selected.id
  instance_type     = var.instance_type
  availability_zone = element(var.avail_zones, count.index)
  subnet_id         = var.subnet_ids == null ? null : length(var.avail_zones) == 1 ? element(var.subnet_ids, 0) : element(var.subnet_ids, count.index)
  source_dest_check = false
  root_block_device {
    volume_size           = var.instance_disk_size
    delete_on_termination = true
  }
  vpc_security_group_ids = [aws_security_group.vms[0].id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.vms[0].name
  user_data              = var.user_data
  lifecycle {
    ignore_changes = [ami, ebs_optimized, user_data]
  }
  tags = merge(local.tags, { Name = "${local.common_tags.Name}-${count.index + var.start_index}" })
}

# instances (spot)

resource "aws_spot_instance_request" "vms" {
  count             = var.spot_price != null ? var.instance_count : 0
  ami               = data.aws_ami.selected.id
  instance_type     = var.instance_type
  availability_zone = element(var.avail_zones, count.index)
  subnet_id         = var.subnet_ids == null ? null : length(var.avail_zones) == 1 ? element(var.subnet_ids, 0) : element(var.subnet_ids, count.index)
  source_dest_check = false
  root_block_device {
    volume_size           = var.instance_disk_size
    delete_on_termination = true
  }
  vpc_security_group_ids = [aws_security_group.vms[0].id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.vms[0].name
  user_data              = var.user_data
  lifecycle {
    ignore_changes = [ami, ebs_optimized, user_data]
  }
  spot_price           = var.spot_price
  wait_for_fulfillment = true
  spot_type            = "one-time"
  # doesn't work
  tags = merge(local.tags, { Name = "${local.common_tags.Name}-${count.index + var.start_index}" })
  # workaround
  provisioner "local-exec" {
    command = "aws ec2 create-tags --resources ${self.spot_instance_id} --tags Key=Name,Value=${local.common_tags.Name}-${count.index + var.start_index} Key=Environment,Value=${var.environment} --region ${var.region}"
  }
}

# ansible

resource "ansible_host" "vms" {
  count              = var.instance_count > 0 ? var.instance_count : 0
  inventory_hostname = "${local.common_tags.Name}-${count.index + var.start_index}"
  groups             = var.ansible_groups
  vars = merge(
    {
      ansible_user                 = var.username
      ansible_ssh_private_key_file = var.key_path != null ? "../${basename(abspath(path.root))}/${var.key_path}" : null
      ansible_host                 = var.elastic_ip_enable ? join("", aws_eip.ip.*.public_dns) : var.spot_price == null ? aws_instance.vms[count.index].public_dns != "" ? aws_instance.vms[count.index].public_dns : aws_instance.vms[count.index].private_dns : aws_spot_instance_request.vms[count.index].public_dns != "" ? aws_spot_instance_request.vms[count.index].public_dns : aws_spot_instance_request.vms[count.index].private_dns
      ansible_ssh_extra_args       = "-o StrictHostKeyChecking=no"
    },
    var.ansible_variables
  )
}
