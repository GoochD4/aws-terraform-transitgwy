resource "aws_vpc" "spoke_vpc1" {
  cidr_block = var.spoke_vpc1_cidr

  tags = {
    Name     = "${var.tag_name_prefix}-vpc-spoke1"
    scenario = var.scenario
  }
}

# Subnets
resource "aws_subnet" "spoke_vpc1-priv1" {
  vpc_id            = aws_vpc.spoke_vpc1.id
  cidr_block        = var.spoke_vpc1_private_subnet_cidr1
  availability_zone = var.availability_zone1

  tags = {
    Name = "${aws_vpc.spoke_vpc1.tags.Name}-priv1"
  }
}

resource "aws_subnet" "spoke_vpc1-priv2" {
  vpc_id            = aws_vpc.spoke_vpc1.id
  cidr_block        = var.spoke_vpc1_private_subnet_cidr2
  availability_zone = var.availability_zone2

  tags = {
    Name = "${aws_vpc.spoke_vpc1.tags.Name}-priv2"
  }
}

# Routes
resource "aws_route_table" "spoke1-rt" {
  vpc_id = aws_vpc.spoke_vpc1.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.TGW-XAZ.id
  }

  tags = {
    Name     = "spoke-vpc1-rt"
    scenario = var.scenario
  }
  depends_on = [aws_ec2_transit_gateway.TGW-XAZ]
}

# Route tables associations
resource "aws_route_table_association" "spoke1_rt_association1" {
  subnet_id      = aws_subnet.spoke_vpc1-priv1.id
  route_table_id = aws_route_table.spoke1-rt.id
}

resource "aws_route_table_association" "spoke1_rt_association2" {
  subnet_id      = aws_subnet.spoke_vpc1-priv2.id
  route_table_id = aws_route_table.spoke1-rt.id
}

# Attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-att-spoke-vpc1" {
  subnet_ids                                      = [aws_subnet.spoke_vpc1-priv1.id, aws_subnet.spoke_vpc1-priv2.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.TGW-XAZ.id
  vpc_id                                          = aws_vpc.spoke_vpc1.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name     = "tgw-att-spoke-vpc1"
    scenario = var.scenario
  }
  depends_on = [aws_ec2_transit_gateway.TGW-XAZ]
}


#Create Spoke 1 security Group
resource "aws_security_group" "NSG-spoke1-ssh-icmp-https" {
  name        = "NSG-spoke1-ssh-icmp-https"
  description = "Allow SSH, HTTPS and ICMP traffic"
  vpc_id      = aws_vpc.spoke_vpc1.id

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
    from_port   = 8 # the ICMP type number for 'Echo'
    to_port     = 0 # the ICMP code
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0 # the ICMP type number for 'Echo Reply'
    to_port     = 0 # the ICMP code
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
    Name     = "NSG-spoke1-ssh-icmp-https"
    scenario = var.scenario
  }
}

# test device in spoke1
resource "aws_instance" "instance-spoke1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.spoke_vpc1-priv1.id
  vpc_security_group_ids = [aws_security_group.NSG-spoke1-ssh-icmp-https.id]
  key_name               = var.keypair

  tags = {
    Name     = "instance-${var.tag_name_unique}-spoke1"
    scenario = var.scenario
    az       = var.availability_zone1
  }
}

# Route Tables Propagations
## This section defines which VPCs will be routed from each Route Table created in the Transit Gateway

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-prp-vpc1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-spoke-vpc1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-VPC-SEC-rt.id
}

# Route Tables Associations
resource "aws_ec2_transit_gateway_route_table_association" "tgw-rt-vpc-spoke1-assoc" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-spoke-vpc1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-spoke-rt.id
}