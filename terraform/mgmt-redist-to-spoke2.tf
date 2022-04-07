#Create redistribution of mgmt to vpc2
resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-prp-mgmt-tovpc2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-spoke-vpc2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-VPC-MGMT-rt.id
}