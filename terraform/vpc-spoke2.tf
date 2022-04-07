resource "aws_vpc" "spoke_vpc2" {
  cidr_block = var.spoke_vpc2_cidr

  tags = {
    Name     = "${var.tag_name_prefix}-vpc-spoke2"
    scenario = var.scenario
  }
}

# Subnets
resource "aws_subnet" "spoke_vpc2-priv1" {
  vpc_id            = aws_vpc.spoke_vpc2.id
  cidr_block        = var.spoke_vpc2_private_subnet_cidr1
  availability_zone = var.availability_zone1

  tags = {
    Name = "${aws_vpc.spoke_vpc2.tags.Name}-priv1"
  }
}

resource "aws_subnet" "spoke_vpc2-priv2" {
  vpc_id            = aws_vpc.spoke_vpc2.id
  cidr_block        = var.spoke_vpc2_private_subnet_cidr2
  availability_zone = var.availability_zone2

  tags = {
    Name = "${aws_vpc.spoke_vpc2.tags.Name}-priv2"
  }
}

# Routes
resource "aws_route_table" "spoke2-rt" {
  vpc_id = aws_vpc.spoke_vpc2.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.TGW-XAZ.id
  }

  tags = {
    Name     = "spoke-vpc2-rt"
    scenario = var.scenario
  }
  depends_on = [aws_ec2_transit_gateway.TGW-XAZ]
}

# Route tables associations
resource "aws_route_table_association" "spoke2_rt_association1" {
  subnet_id      = aws_subnet.spoke_vpc2-priv1.id
  route_table_id = aws_route_table.spoke2-rt.id
}

resource "aws_route_table_association" "spoke2_rt_association2" {
  subnet_id      = aws_subnet.spoke_vpc2-priv2.id
  route_table_id = aws_route_table.spoke2-rt.id
}

# Attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-att-spoke-vpc2" {
  subnet_ids                                      = [aws_subnet.spoke_vpc2-priv1.id, aws_subnet.spoke_vpc2-priv2.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.TGW-XAZ.id
  vpc_id                                          = aws_vpc.spoke_vpc2.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name     = "tgw-att-spoke-vpc2"
    scenario = var.scenario
  }
  depends_on = [aws_ec2_transit_gateway.TGW-XAZ]
}


#Create Security Group for Spoke2
resource "aws_security_group" "NSG-spoke2-ssh-icmp-https" {
  name        = "NSG-spoke2-ssh-icmp-https"
  description = "Allow SSH, HTTPS and ICMP traffic"
  vpc_id      = aws_vpc.spoke_vpc2.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1 # all icmp
    to_port     = -1 # all icmp
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "NSG-spoke2-ssh-icmp-https"
    scenario = var.scenario
  }
}

#TGW Route Table Association
resource "aws_ec2_transit_gateway_route_table_association" "tgw-rt-vpc-spoke2-assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-spoke-vpc2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-spoke-rt.id
}

# Route Tables Propagations
## This section defines which VPCs will be routed from each Route Table created in the Transit Gateway

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-prp-vpc2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-spoke-vpc2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-VPC-SEC-rt.id
}

# test device in spoke2
resource "aws_instance" "instance-spoke2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.spoke_vpc2-priv2.id
  vpc_security_group_ids = [aws_security_group.NSG-spoke2-ssh-icmp-https.id]
  key_name               = var.keypair

  tags = {
    Name     = "instance-${var.tag_name_unique}-spoke2"
    scenario = var.scenario
    az       = var.availability_zone2
  }
}
