################################################################################
# Route Table

resource aws_route_table back {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.tag_prefix}-back"
  }
}

resource aws_route_table_association back_a {
  subnet_id      = aws_subnet.back_a.id
  route_table_id = aws_route_table.back.id
}

resource aws_route back_peering {
  route_table_id            = aws_route_table.back.id
  destination_cidr_block    = var.vpc_peer_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.oregon_to_tokyo.id
}
