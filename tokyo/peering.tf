################################################################################
# vpc peering accepter

resource aws_vpc_peering_connection_accepter oregon_to_tokyo {
  vpc_peering_connection_id = var.vpc_peer_requester_id
  auto_accept               = true
}

resource aws_vpc_peering_connection_options oregon_to_tokyo {
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.oregon_to_tokyo.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

output vpc_peering_accepter_id {
  value = aws_vpc_peering_connection_accepter.oregon_to_tokyo.id
}
