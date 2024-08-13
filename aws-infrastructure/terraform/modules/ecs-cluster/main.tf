# ecs

resource "aws_ecs_cluster" "default" {
  name = local.tags.Name
  tags = local.tags
}
