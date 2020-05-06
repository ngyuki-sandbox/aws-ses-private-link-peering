################################################################################
# vpc peering requester

resource aws_vpc_peering_connection oregon_to_tokyo {
  vpc_id      = aws_vpc.main.id
  peer_region = var.vpc_peer_region
  peer_vpc_id = var.vpc_peer_vpc_id
}

resource aws_vpc_peering_connection_options oregon_to_tokyo {
  # accept した後でなければ設定できない
  # requester でも id は同じだけど依存関係のために accepter を指定する
  vpc_peering_connection_id = var.vpc_peer_accepter_id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

output vpc_peering_requester_id {
  value = aws_vpc_peering_connection.oregon_to_tokyo.id
}
