resource "aws_vpc" "spoke_mgmt" {
  cidr_block = var.mgmt_cidr

  tags = {
    Name     = "${var.tag_name_prefix}-vpc-mgmt"
    scenario = var.scenario
  }
}

# IGW
resource "aws_internet_gateway" "igw_mgmt" {
  vpc_id = aws_vpc.spoke_mgmt.id
  tags = {
    Name = "${var.tag_name_prefix}-${var.tag_name_unique}-igw_mgmt"
  }
}

# Subnets
resource "aws_subnet" "spoke_mgmt-priv1" {
  vpc_id            = aws_vpc.spoke_mgmt.id
  cidr_block        = var.mgmt_private_subnet_cidr1
  availability_zone = var.availability_zone1

  tags = {
    Name = "${aws_vpc.spoke_mgmt.tags.Name}-priv1"
  }
}

resource "aws_subnet" "spoke_mgmt-priv2" {
  vpc_id            = aws_vpc.spoke_mgmt.id
  cidr_block        = var.mgmt_private_subnet_cidr2
  availability_zone = var.availability_zone2

  tags = {
    Name = "${aws_vpc.spoke_mgmt.tags.Name}-priv2"
  }
}

# Routes
resource "aws_route_table" "mgmt-rt" {
  vpc_id = aws_vpc.spoke_mgmt.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_mgmt.id
  }
  route {
    cidr_block         = var.spoke_vpc1_cidr
    transit_gateway_id = aws_ec2_transit_gateway.TGW-XAZ.id
  }
  route {
    cidr_block         = var.spoke_vpc2_cidr
    transit_gateway_id = aws_ec2_transit_gateway.TGW-XAZ.id
  }

  tags = {
    Name     = "mgmt-rt"
    scenario = var.scenario
  }
  depends_on = [aws_ec2_transit_gateway.TGW-XAZ]
}

# Route tables associations
resource "aws_route_table_association" "mgmtvpc_rt_association1" {
  subnet_id      = aws_subnet.spoke_mgmt-priv1.id
  route_table_id = aws_route_table.mgmt-rt.id
}

resource "aws_route_table_association" "mgmtvpc_rt_association2" {
  subnet_id      = aws_subnet.spoke_mgmt-priv2.id
  route_table_id = aws_route_table.mgmt-rt.id
}

# Attachment to TGW
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-att-mgmt" {
  subnet_ids                                      = [aws_subnet.spoke_mgmt-priv1.id, aws_subnet.spoke_mgmt-priv2.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.TGW-XAZ.id
  vpc_id                                          = aws_vpc.spoke_mgmt.id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags = {
    Name     = "tgw-att-spoke-mgmt"
    scenario = var.scenario
  }
  depends_on = [aws_ec2_transit_gateway.TGW-XAZ]
}

#Create TGW RT for MGMT VPC
resource "aws_ec2_transit_gateway_route_table" "TGW-VPC-MGMT-rt" {
  depends_on = [aws_ec2_transit_gateway.TGW-XAZ]
  transit_gateway_id = aws_ec2_transit_gateway.TGW-XAZ.id
  tags = {
    Name     = "TGW-VPC-MGMT-RT"
    scenario = var.scenario
  }
}

#TGW Routes from Spokes to MGMT
resource "aws_ec2_transit_gateway_route" "spokes_to-mgmt" {
  destination_cidr_block         = var.mgmt_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-mgmt.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-spoke-rt.id
}

#Create Rout Table association for TGW to MGMT
resource "aws_ec2_transit_gateway_route_table_association" "tgw-rt-vpc_mgmt" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-mgmt.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-VPC-MGMT-rt.id
}

# Route Tables Propagations MGMT to other VPCs
resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-prp-mgmt-tovpc1" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-spoke-vpc1.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-VPC-MGMT-rt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "tgw-rt-prp-mgmt-tovpc2" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.tgw-att-spoke-vpc2.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.TGW-VPC-MGMT-rt.id
}

#Create Security Group
resource "aws_security_group" "NSG-mgmt-ssh-icmp-https" {
  name        = "NSG-mgmt-ssh-icmp-https"
  description = "Allow SSH, HTTPS and ICMP traffic"
  vpc_id      = aws_vpc.spoke_mgmt.id

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
    from_port   = -1 # the ICMP type number for 'Echo Reply'
    to_port     = -1 # the ICMP code
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
    Name     = "NSG-mgmt-ssh-icmp-https"
    scenario = var.scenario
  }
}


# test device in mgmt
resource "aws_instance" "instance-mgmt" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.spoke_mgmt-priv1.id
  vpc_security_group_ids      = [aws_security_group.NSG-mgmt-ssh-icmp-https.id]
  key_name                    = var.keypair
  associate_public_ip_address = true

  tags = {
    Name     = "instance-${var.tag_name_unique}-mgmt"
    scenario = var.scenario
    az       = var.availability_zone1
  }
}

#output MGMT linux Public IP
output "Linux_Public_IP" {
    value = aws_instance.instance-mgmt.public_ip
    description = "Linux Instance Public IP"
}