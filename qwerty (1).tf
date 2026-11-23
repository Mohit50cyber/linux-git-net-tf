	terraform {
	  required_providers {
		aws = {
		  source  = "hashicorp/aws"                         # AWS provider HashiCorp se download hoga.
		  version = "6.0"                                  # Provider version 6 use karni hai.
		}
	  }
	}

	provider "aws" {
	  region = "ap-south-1"                                # Mumbai region me resources create honge.
	}

	########################################################
	# Fetch Latest Ubuntu AMI Automatically
	########################################################

	data "aws_ami" "ubuntu" {
	  most_recent = true                                   # Latest Ubuntu AMI automatically pick karega.
	  owners      = ["099720109477"]                       # Canonical (Ubuntu official publisher) ka account ID.

	  filter {
		name   = "name"                                    # AMI ka name filter kar rahe hain.
		values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]  # Ubuntu 24.04 GP3 SSD Server AMI.
	  }
	}

	########################################################
	# Fetch Default VPC
	########################################################

	data "aws_vpc" "default" {
	  default = true                                       # Existing default VPC use karega.
	}

	########################################################
	# Fetch Default Subnets
	########################################################

	data "aws_subnets" "default" {
	  filter {
		name   = "vpc-id"                                  # VPC ke andar ke subnets fetch karega.
		values = [data.aws_vpc.default.id]                 # Default VPC ID ko filter me pass kar rahe hain.
	  }
	}

	########################################################
	# Create Security Group
	########################################################

	resource "aws_security_group" "web_sg" {
	  name        = "terraform-web-sg"                     # Security Group ka naam.
	  description = "Allow SSH and HTTP"                   # Description sirf identification ke liye.
	  vpc_id      = data.aws_vpc.default.id                # Security Group default VPC me create hoga.

	  ingress {
		description = "SSH Access"                         # SSH access allow karega.
		from_port   = 22                                  # SSH start port.
		to_port     = 22                                  # SSH end port.
		protocol    = "tcp"                               # TCP protocol allow.
		cidr_blocks = ["0.0.0.0/0"]                       # Kisi bhi IP se SSH allow.
	  }

	  ingress {
		description = "HTTP Access"                        # HTTP traffic allow karega.
		from_port   = 80                                  # HTTP port.
		to_port     = 80
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]                       # Internet se website access hogi.
	  }

	  egress {
		from_port   = 0                                   # Sab outbound ports allow.
		to_port     = 0
		protocol    = "-1"                                # -1 matlab all protocols.
		cidr_blocks = ["0.0.0.0/0"]                       # Internet me kahin bhi request bhej sakta hai.
	  }

	  tags = {
		Name = "terraform-web-sg"                          # AWS Console me naam dikhega.
	  }
	}

	########################################################
	# Create 2 EC2 Instances (Using Count)
	########################################################

	resource "aws_instance" "web_server" {

	  count = 2                                            # Total 2 EC2 create honge.

	  ami           = data.aws_ami.ubuntu.id               # Latest Ubuntu AMI use karega.
	  instance_type = "t2.micro"                           # EC2 instance type.
	  key_name      = "terraform-01"                       # Existing Key Pair ka naam.

	  subnet_id = data.aws_subnets.default.ids[count.index % 2]  # EC2 ko alternate subnet me create karega.

	  associate_public_ip_address = true                   # Public IP assign karega.

	  vpc_security_group_ids = [aws_security_group.web_sg.id]     # Security Group attach karega.

	  ######################################################
	  # User Data (Nginx for EC2-1, Apache for EC2-2)
	  ######################################################

	  user_data = count.index == 0 ? <<-NGINX : <<-APACHE
	#!/bin/bash
	apt-get update -y
	apt-get install nginx -y
	systemctl enable nginx
	systemctl start nginx

	echo "<h1>Nginx Server</h1>" > /var/www/html/index.html
	echo "<h2>Hostname : $(hostname)</h2>" >> /var/www/html/index.html
	echo "<h3>Created by Terraform</h3>" >> /var/www/html/index.html
	NGINX
	#!/bin/bash
	apt-get update -y
	apt-get install apache2 -y
	systemctl enable apache2
	systemctl start apache2

	echo "<h1>Apache Server</h1>" > /var/www/html/index.html
	echo "<h2>Hostname : $(hostname)</h2>" >> /var/www/html/index.html
	echo "<h3>Created by Terraform</h3>" >> /var/www/html/index.html
	APACHE

	  # count.index == 0 → Nginx install karega.
	  # count.index == 1 → Apache install karega.

	  tags = {
		Name = count.index == 0 ? "Nginx-Server" : "Apache-Server"   # EC2 ko different names milenge.
	  }
	}

	########################################################
	# Create 2 EBS Volumes (10 GB Each)
	########################################################

	resource "aws_ebs_volume" "extra_volume" {

	  count = 2                                             # Dono EC2 ke liye 2 EBS create honge.

	  availability_zone = aws_instance.web_server[count.index].availability_zone
	  # Har EBS usi Availability Zone me create hoga jahan EC2 hai.

	  size = 10                                              # 10 GB EBS volume.

	  type = "gp3"                                           # GP3 SSD storage type.

	  tags = {
		Name = "EBS-Volume-${count.index + 1}"               # EBS-Volume-1 aur EBS-Volume-2.
	  }
	}

	########################################################
	# Attach EBS Volume to Each EC2
	########################################################

	resource "aws_volume_attachment" "ebs_attach" {

	  count = 2                                              # 2 attachments create honge.

	  device_name = "/dev/sdf"                               # Linux me EBS attach hone ka device path.

	  volume_id = aws_ebs_volume.extra_volume[count.index].id
	  # Correct EBS Volume attach karega.

	  instance_id = aws_instance.web_server[count.index].id
	  # Correct EC2 ke saath attach karega.

	  force_detach = true                                    # Destroy ke time force detach karega.
	}

	########################################################
	# Outputs
	########################################################

	output "ec2_public_ips" {
	  value = aws_instance.web_server[*].public_ip            # Dono EC2 ke Public IP ek list me print honge.
	}

	output "ec2_public_dns" {
	  value = aws_instance.web_server[*].public_dns           # Dono EC2 ke Public DNS print honge.
	}

	output "ebs_volume_ids" {
	  value = aws_ebs_volume.extra_volume[*].id               # Dono EBS Volume IDs print honge.
	}




--------------------------------------------------------------------------------------------------------------------------------------------------



########################################################
# 9. Create a VPC from scratch
########################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"                  # VPC ka IP range define ho raha hai.
  enable_dns_support   = true                            # DNS resolution VPC ke andar enable hoga.
  enable_dns_hostnames = true                            # Instances ko DNS hostname milega.

  tags = {
    Name = "terraform-vpc"                               # Console me VPC ka naam dikhega.
  }
}

########################################################
# 10. Create Public and Private Subnets
########################################################

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id              # Ye subnet upar wali VPC ke andar banega.
  cidr_block               = "10.0.1.0/24"               # Public subnet ka IP range.
  availability_zone        = "ap-south-1a"               # Mumbai region ka AZ-1.
  map_public_ip_on_launch  = true                        # Is subnet me launch hone wale instance ko public IP milega.

  tags = {
    Name = "public-subnet"                                # Public subnet ka naam.
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id                    # Ye subnet bhi same VPC ke andar banega.
  cidr_block        = "10.0.2.0/24"                      # Private subnet ka IP range.
  availability_zone = "ap-south-1b"                      # Dusra AZ use kar rahe hain.

  tags = {
    Name = "private-subnet"                               # Private subnet ka naam.
  }
}

########################################################
# 11. Create Internet Gateway (IGW)
########################################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id                                # IGW ko VPC ke saath attach kar rahe hain.

  tags = {
    Name = "terraform-igw"                                 # IGW ka naam.
  }
}

########################################################
# 12. Create Route Table and associate with Public Subnet
########################################################

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id                                # Route table VPC ke andar banegi.

  route {
    cidr_block = "0.0.0.0/0"                              # Sab traffic ke liye default route.
    gateway_id = aws_internet_gateway.igw.id               # Traffic ko IGW ke through internet bhejega.
  }

  tags = {
    Name = "public-route-table"                            # Route table ka naam.
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id                   # Public subnet ko route table se jod rahe hain.
  route_table_id = aws_route_table.public_rt.id            # Upar wali public route table use hogi.
}

########################################################
# 13. Create NAT Gateway for Private Subnet
########################################################

resource "aws_eip" "nat_eip" {
  domain = "vpc"                                          # NAT Gateway ke liye Elastic IP chahiye hoti hai.

  tags = {
    Name = "nat-eip"                                       # Elastic IP ka naam.
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id                       # Upar wali Elastic IP NAT Gateway ko assign hogi.
  subnet_id     = aws_subnet.public.id                     # NAT Gateway hamesha PUBLIC subnet me hi banta hai.

  tags = {
    Name = "terraform-nat-gateway"                          # NAT Gateway ka naam.
  }

  depends_on = [aws_internet_gateway.igw]                   # IGW pehle create hona chahiye, tabhi NAT banega.
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id                                 # Private route table bhi same VPC me banegi.

  route {
    cidr_block     = "0.0.0.0/0"                           # Sab outbound traffic ke liye default route.
    nat_gateway_id = aws_nat_gateway.nat.id                 # Private subnet ka traffic NAT Gateway se hoke jayega.
  }

  tags = {
    Name = "private-route-table"                            # Private route table ka naam.
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id                   # Private subnet ko route table se jod rahe hain.
  route_table_id = aws_route_table.private_rt.id            # Upar wali private route table use hogi.
}

########################################################
# 14. Create Security Groups (SSH, HTTP, HTTPS)
########################################################

resource "aws_security_group" "web_sg" {
  name        = "vpc-web-sg"                               # Security Group ka naam.
  description = "Allow SSH, HTTP and HTTPS"                 # Description identification ke liye.
  vpc_id      = aws_vpc.main.id                             # Ye SG naye VPC ke andar banega.

  ingress {
    description = "SSH Access"                              # SSH ke liye rule.
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                             # Kisi bhi IP se SSH allow (production me restrict karna chahiye).
  }

  ingress {
    description = "HTTP Access"                             # HTTP traffic allow karega.
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                             # Internet se website access.
  }

  ingress {
    description = "HTTPS Access"                            # HTTPS traffic allow karega.
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                             # Secure website access allow.
  }

  egress {
    from_port   = 0                                         # Sab outbound ports allow.
    to_port     = 0
    protocol    = "-1"                                      # -1 matlab all protocols.
    cidr_blocks = ["0.0.0.0/0"]                             # Kahin bhi outbound request bhej sakta hai.
  }

  tags = {
    Name = "vpc-web-sg"                                      # Console me naam dikhega.
  }
}

########################################################
# 15. Create Network ACL
########################################################

resource "aws_network_acl" "main_nacl" {
  vpc_id     = aws_vpc.main.id                              # NACL VPC level pe kaam karta hai.
  subnet_ids = [aws_subnet.public.id, aws_subnet.private.id]  # Dono subnets is NACL se associate honge.

  ingress {
    rule_no    = 100                                        # Rule ka priority number (chota number pehle check hota hai).
    protocol   = "tcp"
    action     = "allow"                                    # Ye traffic allow karega.
    cidr_block = "0.0.0.0/0"
    from_port  = 22                                         # SSH inbound allow.
    to_port    = 22
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80                                         # HTTP inbound allow.
    to_port    = 80
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443                                        # HTTPS inbound allow.
    to_port    = 443
  }

  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024                                       # Ephemeral ports allow (return traffic ke liye zaroori).
    to_port    = 65535
  }

  egress {
    rule_no    = 100
    protocol   = "-1"                                       # Sab outbound traffic allow.
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "terraform-nacl"                                  # NACL ka naam.
  }
}

########################################################
# Outputs
########################################################

output "vpc_id" {
  value = aws_vpc.main.id                                    # VPC ID print hoga.
}

output "public_subnet_id" {
  value = aws_subnet.public.id                               # Public subnet ID print hoga.
}

output "private_subnet_id" {
  value = aws_subnet.private.id                              # Private subnet ID print hoga.
}

output "nat_gateway_ip" {
  value = aws_eip.nat_eip.public_ip                          # NAT Gateway ka public IP print hoga.
}






-------------------------------------------------------------------------------------------------------------------------------------------------



terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"                     # AWS provider HashiCorp se download hoga.
      version = "6.0"                              # Provider version 6 use karni hai.
    }
  }
}

provider "aws" {
  region = "ap-south-1"                            # Mumbai region me saare resources create honge.
}

##########################################################
# Fetch Latest Ubuntu AMI Automatically
##########################################################

data "aws_ami" "ubuntu" {
  most_recent = true                               # Latest Ubuntu image automatically pick karega.
  owners      = ["099720109477"]                   # Canonical Ubuntu ka official owner ID.

  filter {
    name   = "name"                                # AMI name pe filter laga rahe hain.
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]  # Ubuntu 24.04 LTS GP3 SSD Server AMI.
  }
}

##########################################################
# Fetch Default VPC
##########################################################

data "aws_vpc" "default" {
  default = true                                   # Existing Default VPC use hogi.
}

##########################################################
# Fetch All Default Public Subnets
##########################################################

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"                              # Default VPC ke andar ke subnets fetch karega.
    values = [data.aws_vpc.default.id]             # values list hoti hai isliye [] use kiya.
  }
}

##########################################################
# Security Group for ALB + EC2
##########################################################

resource "aws_security_group" "alb_sg" {

  name        = "terraform-alb-sg"                 # Security Group ka naam.
  description = "Allow SSH and HTTP"              # Identification ke liye description.
  vpc_id      = data.aws_vpc.default.id            # Default VPC me create hoga.

  ingress {
    description = "SSH Access"
    from_port   = 22                              # SSH Port.
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                   # Internet se SSH allow.
  }

  ingress {
    description = "HTTP Access"
    from_port   = 80                              # HTTP traffic allow.
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                   # Website internet se access hogi.
  }

  egress {
    from_port   = 0                               # All outbound traffic allow.
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-alb-sg"
  }
}

##########################################################
# Create 5 Ubuntu EC2 Instances
##########################################################

resource "aws_instance" "web_server" {

  count = 5                                       # Total 5 EC2 instances create honge.

  ami           = data.aws_ami.ubuntu.id          # Latest Ubuntu AMI use hogi.
  instance_type = "t2.micro"
  key_name      = "terraform-01"

  subnet_id = data.aws_subnets.default.ids[count.index % 2]
  # count.index => 0,1,2,3,4
  # %2 => 0,1,0,1,0
  # EC2 alternate subnet me create honge for High Availability.

  associate_public_ip_address = true              # Har EC2 ko Public IP milega.

  vpc_security_group_ids = [aws_security_group.alb_sg.id]
  # Upar create kiya hua Security Group attach hoga.

  ########################################################
  # Install Nginx Automatically
  ########################################################

  user_data = <<-EOF
#!/bin/bash

apt-get update -y
apt-get install nginx -y

systemctl enable nginx
systemctl start nginx

echo "<h1>EC2 Server ${count.index + 1}</h1>" > /var/www/html/index.html

echo "<h2>Target Group : ${count.index < 2 ? "BLUE" : count.index < 4 ? "GREEN" : "RED"}</h2>" >> /var/www/html/index.html

echo "<h3>Hostname : $(hostname)</h3>" >> /var/www/html/index.html

echo "<h3>Created through Terraform</h3>" >> /var/www/html/index.html
EOF

  tags = {
    Name = "Web-Server-${count.index + 1}"        # Web-Server-1 ... Web-Server-5.
  }
}


##########################################################
# Application Load Balancer
##########################################################

resource "aws_lb" "alb" {                                    # aws_lb resource AWS me Application Load Balancer create karta hai.

  name = "terraform-alb"                                     # ALB ka unique naam. AWS account + region me unique hona chahiye.

  internal = false                                           # false matlab Internet Facing ALB. Browser ya internet se access hoga.
                                                             # true hota to sirf VPC ke andar accessible hota.

  load_balancer_type = "application"                         # ALB create kar rahe hain. Layer-7 Load Balancer.
                                                             # HTTP/HTTPS traffic ko intelligently route karta hai.

  security_groups = [aws_security_group.alb_sg.id]           # ALB pe firewall attach kar rahe hain.
                                                             # Ye Security Group decide karega kaunsa traffic ALB tak aa sakta hai.

  subnets = data.aws_subnets.default.ids                     # ALB minimum 2 public subnets me deploy hota hai.
                                                             # High Availability ke liye AWS ALB ko multiple AZ me place karta hai.

  tags = {
    Name = "terraform-alb"                                   # AWS Console me easily identify karne ke liye tag.
  }
}

##########################################################
# BLUE Target Group
##########################################################

resource "aws_lb_target_group" "blue_tg" {                   # Ye BLUE Target Group create karega.

  name = "blue-target-group"                                # Target Group ka naam.

  port = 80                                                 # ALB traffic EC2 ke port 80 pe bhejega.

  protocol = "HTTP"                                         # HTTP protocol use karega.

  vpc_id = data.aws_vpc.default.id                          # Target Group isi VPC ke EC2 instances ko register karega.

  health_check {                                            # ALB har EC2 ko continuously monitor karta hai.

    path = "/"                                              # Root URL hit karega. Nginx homepage check hogi.

    port = "traffic-port"                                   # Jis port pe traffic ja raha hai usi port pe health check karega.
  }

  tags = {
    Name = "BLUE-TG"                                        # Console me BLUE Target Group dikhega.
  }
}

##########################################################
# GREEN Target Group
##########################################################

resource "aws_lb_target_group" "green_tg" {                 # GREEN Target Group create karega.

  name = "green-target-group"                               # GREEN TG ka naam.

  port = 80                                                 # Traffic EC2 ke HTTP port pe jayega.

  protocol = "HTTP"                                         # HTTP communication.

  vpc_id = data.aws_vpc.default.id                          # Same VPC me EC2 register honge.

  health_check {
    path = "/"                                              # Homepage health check.
    port = "traffic-port"                                   # EC2 ke listening port pe check karega.
  }

  tags = {
    Name = "GREEN-TG"
  }
}

##########################################################
# RED Target Group
##########################################################

resource "aws_lb_target_group" "red_tg" {                   # RED Target Group create karega.

  name = "red-target-group"

  port = 80                                                 # HTTP traffic receive karega.

  protocol = "HTTP"

  vpc_id = data.aws_vpc.default.id                          # Same VPC ke EC2 hi attach ho sakte hain.

  health_check {
    path = "/"                                              # Root page check karega.
    port = "traffic-port"
  }

  tags = {
    Name = "RED-TG"
  }
}

##########################################################
# Attach EC2-1 & EC2-2 to BLUE Target Group
##########################################################

resource "aws_lb_target_group_attachment" "blue_attach" {

  count = 2                                                 # Do attachment resources create honge.

  target_group_arn = aws_lb_target_group.blue_tg.arn        # Kis Target Group me EC2 attach karna hai.

  target_id = aws_instance.web_server[count.index].id       # count.index = 0 aur 1.
                                                            # Matlab EC2-1 aur EC2-2 BLUE TG me attach honge.

  port = 80                                                 # ALB EC2 ke port 80 pe traffic bhejega.
}

##########################################################
# Attach EC2-3 & EC2-4 to GREEN Target Group
##########################################################

resource "aws_lb_target_group_attachment" "green_attach" {

  count = 2                                                 # Do EC2 attach honge.

  target_group_arn = aws_lb_target_group.green_tg.arn       # GREEN TG select kiya.

  target_id = aws_instance.web_server[count.index + 2].id   # count.index 0,1 hota hai.
                                                            # +2 karne se index 2 aur 3 milta hai.
                                                            # Matlab EC2-3 aur EC2-4 GREEN TG me jayenge.

  port = 80                                                 # HTTP traffic receive karega.
}

##########################################################
# Attach EC2-5 to RED Target Group
##########################################################

resource "aws_lb_target_group_attachment" "red_attach" {

  target_group_arn = aws_lb_target_group.red_tg.arn         # RED TG choose kiya.

  target_id = aws_instance.web_server[4].id                 # Directly 5th EC2 ka index use kiya.
                                                            # Terraform indexing 0 se start hoti hai.

  port = 80
}

##########################################################
# ALB Listener (Port 80)
##########################################################

resource "aws_lb_listener" "http_listener" {

  load_balancer_arn = aws_lb.alb.arn                        # Listener ko kis ALB pe create karna hai.

  port = 80                                                 # ALB browser ki request port 80 pe listen karega.

  protocol = "HTTP"                                         # HTTP protocol accept karega.

  default_action {                                          # Agar koi rule match nahi hua to kya karna hai.

    type = "forward"                                        # Request ko kisi Target Group me forward karega.

    target_group_arn = aws_lb_target_group.blue_tg.arn      # Default traffic BLUE TG ko jayega.
  }
}

##########################################################
# Listener Rule - GREEN Traffic
##########################################################

resource "aws_lb_listener_rule" "green_rule" {

  listener_arn = aws_lb_listener.http_listener.arn          # Existing Listener pe rule add kar rahe hain.

  priority = 10                                             # Sabse pehle ye rule evaluate hoga.

  action {
    type = "forward"                                        # Match hone pe GREEN TG me traffic bhejo.

    target_group_arn = aws_lb_target_group.green_tg.arn
  }

  condition {
    path_pattern {

      values = ["/green*"]                                  # URL /green ya /green/home match karega.
    }
  }
}


##########################################################
# Listener Rule - RED Traffic
##########################################################

resource "aws_lb_listener_rule" "red_rule" {

  listener_arn = aws_lb_listener.http_listener.arn          # Same Listener pe second rule.

  priority = 20                                             # BLUE default ke baad RED rule evaluate hoga.

  action {
    type = "forward"

    target_group_arn = aws_lb_target_group.red_tg.arn       # RED TG ko traffic forward karega.
  }

  condition {
    path_pattern {

      values = ["/red*"]                                    # URL /red hit karega to RED TG me jayega.
    }
  }
}

##########################################################
# Outputs
##########################################################

output "alb_dns_name" {

  value = aws_lb.alb.dns_name                              # ALB ka public DNS print karega.
                                                           # Browser me isi DNS ko open karoge.
}

output "ec2_public_ips" {

  value = aws_instance.web_server[*].public_ip             # 5 EC2 ke public IP list form me print honge.
}

output "blue_target_group_arn" {

  value = aws_lb_target_group.blue_tg.arn                  # BLUE Target Group ka ARN output me milega.
}

output "green_target_group_arn" {

  value = aws_lb_target_group.green_tg.arn                 # GREEN Target Group ARN.
}

output "red_target_group_arn" {

  value = aws_lb_target_group.red_tg.arn                   # RED Target Group ARN.
}




--------------------------------------------------------------------------------------------------------------------------------------------------



############################################################
# Terraform Provider
############################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"                       # Terraform ko batata hai ki AWS provider HashiCorp Registry se download karna hai.
      version = "6.0"                                # Provider ka exact version 6.0 lock kar diya taaki future me breaking changes na aayein.
    }
  }
}

provider "aws" {
  region = "ap-south-1"                              # Ye batata hai ki saare resources kis AWS region (Mumbai) me create honge.
}

############################################################
# Fetch Latest Ubuntu AMI
############################################################

data "aws_ami" "ubuntu" {
  most_recent = true                                 # Agar multiple AMIs match hue to sabse latest (naya) wala automatically select karega.
  owners      = ["099720109477"]                     # Ye Canonical company ka official AWS Account ID hai, jo Ubuntu AMIs publish karti hai — isse fake/unsafe AMI avoid hoti hai.

  filter {
    name   = "name"                                  # Filter ka type "name" hai, matlab AMI ke naam ke basis pe search hogi.
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
    # Ye pattern sirf Ubuntu 24.04 (Noble) ke HVM + GP3 SSD based server images ko match karega, purane versions ignore ho jayenge.
  }
}

############################################################
# Fetch Default VPC
############################################################

data "aws_vpc" "default" {
  default = true                                     # Naya VPC banane ke bajaye, AWS account me pehle se maujood "Default VPC" ko fetch kar raha hai.
}

############################################################
# Fetch Default Public Subnets
############################################################

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"                                # Filter batata hai ki subnets kis VPC ke andar se fetch karne hain.
    values = [data.aws_vpc.default.id]                # Upar wali Default VPC ka ID pass kiya gaya hai, taaki usi VPC ke saare subnets mil jayein.
  }
}

############################################################
# Security Group
############################################################

resource "aws_security_group" "web_sg" {

  name        = "asg-alb-sg"                         # Security Group ka naam — ye ek hi SG hai jo ALB aur EC2 Instances dono pe use hoga.
  description = "Allow SSH and HTTP"                  # Description sirf documentation ke liye hai, AWS Console me dikhta hai.
  vpc_id      = data.aws_vpc.default.id                # Ye Security Group Default VPC ke andar hi banega (VPC ke bahar SG nahi ban sakta).

  ingress {
    description = "SSH Access"                        # Ye rule server me remote login (SSH) ke liye traffic allow karta hai.
    from_port   = 22                                  # SSH protocol hamesha port 22 use karta hai.
    to_port     = 22                                  # Same port from aur to dono me diya gaya hai, matlab sirf port 22 open hoga.
    protocol    = "tcp"                                # SSH TCP protocol pe kaam karta hai.
    cidr_blocks = ["0.0.0.0/0"]                        # 0.0.0.0/0 ka matlab hai duniya ki kisi bhi IP se access allowed hai (production me isko apni IP tak restrict karna better hota hai).
  }

  ingress {
    description = "HTTP Access"                        # Ye rule website/browser traffic ke liye hai.
    from_port   = 80                                  # HTTP web traffic ka default port 80 hota hai.
    to_port     = 80
    protocol    = "tcp"                                # HTTP bhi TCP based protocol hai.
    cidr_blocks = ["0.0.0.0/0"]                        # Internet se koi bhi user website open kar sakta hai.
  }

  egress {
    from_port   = 0                                   # Port 0 se 0 tak matlab saare ports allow hain outbound ke liye.
    to_port     = 0
    protocol    = "-1"                                # "-1" ek special value hai jiska matlab hai "sab protocols" (TCP, UDP, ICMP sab).
    cidr_blocks = ["0.0.0.0/0"]                        # Instance internet me kahin bhi outbound request bhej sakta hai (jaise updates download karna, API calls karna).
  }

  tags = {
    Name = "asg-alb-sg"                                 # AWS Console me is Security Group ka naam is tag se dikhega.
  }
}

############################################################
# Launch Template
############################################################

resource "aws_launch_template" "web_lt" {

  name_prefix = "terraform-launch-template-"          # Launch Template ka naam is prefix ke saath ek random suffix jodkar banega, taaki naming conflict na ho.

  image_id      = data.aws_ami.ubuntu.id              # Auto Scaling Group jab bhi naya EC2 banayega, ye wahi Ubuntu AMI use karega jo upar fetch kiya tha.
  instance_type = "t2.micro"                          # Ye instance size/type hai — t2.micro Free Tier eligible hota hai, low compute workloads ke liye.
  key_name      = "terraform-01"                      # Ye pehle se AWS me banaya hua SSH Key Pair hai, isi se EC2 me login hoga.

  vpc_security_group_ids = [aws_security_group.web_sg.id]
  # Launch Template se jitni bhi EC2 instances banengi (ASG ke through), unn sab pe ye Security Group automatically attach ho jayega.

  user_data = base64encode(<<-EOF
#!/bin/bash

apt-get update -y
apt-get install nginx -y

systemctl enable nginx
systemctl start nginx

echo "<h1>Auto Scaling EC2</h1>" > /var/www/html/index.html
echo "<h2>Hostname : $(hostname)</h2>" >> /var/www/html/index.html
echo "<h3>Created through Launch Template</h3>" >> /var/www/html/index.html
EOF
  )
  # Ye "user_data" script hai jo EC2 ke pehli baar boot hote hi automatically chalti hai (cloud-init ke through).
  # Isme system update hota hai, Nginx install/start hota hai, aur ek simple HTML homepage bana di jaati hai jisme hostname bhi dikhta hai.
  # base64encode() isliye use kiya gaya hai kyunki AWS Launch Template user_data field me Base64 encoded string expect karta hai — ye Terraform/AWS ka standard requirement hai.

  tag_specifications {
    resource_type = "instance"                        # Ye batata hai ki neeche diye gaye tags kis resource type (yahan EC2 instance) pe apply honge.

    tags = {
      Name = "ASG-Web-Server"                          # Auto Scaling Group se launch hone wali har EC2 ka naam "ASG-Web-Server" hoga.
    }
  }
}

############################################################
# Application Load Balancer
############################################################

resource "aws_lb" "alb" {

  name               = "terraform-alb"                # Load Balancer ka naam, AWS Console me isi naam se dikhega.
  internal           = false                           # false ka matlab hai ye Load Balancer Internet-Facing hai, matlab isko public internet se access kiya ja sakta hai.
  load_balancer_type = "application"                  # "application" type ALB banata hai jo Layer-7 (HTTP/HTTPS) traffic handle karta hai, path/host based routing support karta hai.

  security_groups = [aws_security_group.web_sg.id]    # ALB pe bhi wahi Security Group attach hai, taaki incoming traffic control ho sake.

  subnets = data.aws_subnets.default.ids               # ALB ko multiple Availability Zones ke subnets diye gaye hain — high availability ke liye ALB kam se kam 2 AZ me hona chahiye.

  tags = {
    Name = "terraform-alb"                              # Console me is ALB ka naam is tag se dikhega.
  }
}

############################################################
# Target Group
############################################################

resource "aws_lb_target_group" "web_tg" {

  name     = "terraform-web-tg"                        # Target Group ka naam — ye group batata hai ki traffic kin EC2 instances tak forward hoga.
  port     = 80                                        # ALB, EC2 instances ke is port (80) pe traffic bhejega.
  protocol = "HTTP"                                     # Target Group aur EC2 ke beech communication HTTP protocol pe hogi.

  vpc_id = data.aws_vpc.default.id                      # Target Group usi VPC ke andar banegi jisme EC2 instances hain, warna ye kaam nahi karega.

  health_check {
    path                = "/"                            # ALB is path (homepage "/") ko periodically hit karke check karega ki instance healthy hai ya nahi.
    protocol            = "HTTP"                          # Health check bhi HTTP protocol se hi hoga.
    matcher             = "200"                           # Agar response me HTTP Status Code 200 mile to instance ko "Healthy" mana jayega.
    healthy_threshold   = 2                               # Lagatar 2 baar successful response aane par instance ko healthy declare kar dega.
    unhealthy_threshold = 2                               # Lagatar 2 baar fail hone par instance ko unhealthy mark karke traffic bhejna band kar dega.
    interval            = 30                              # Har 30 second me ek health check request bheji jayegi.
    timeout             = 5                                # Agar 5 second ke andar response nahi mila to request ko fail maana jayega.
  }

  tags = {
    Name = "terraform-web-tg"                            # Console me Target Group ka naam is tag se dikhega.
  }
}

############################################################
# ALB Listener
############################################################

resource "aws_lb_listener" "listener" {

  load_balancer_arn = aws_lb.alb.arn                    # Ye Listener batata hai ki ye kis specific Load Balancer (ALB) ke liye configure ho raha hai.

  port     = 80                                          # Users jab browser me website kholenge to unki request is port (80) pe ALB tak pahunchegi.
  protocol = "HTTP"                                       # Incoming client traffic HTTP protocol me accept hoga.

  default_action {
    type             = "forward"                          # "forward" action ka matlab hai matching traffic ko directly Target Group tak bhej diya jayega.
    target_group_arn = aws_lb_target_group.web_tg.arn      # Traffic isi Target Group (upar defined) ko forward hoga, jo aage EC2 instances tak route karega.
  }
}

############################################################
# Auto Scaling Group
############################################################

resource "aws_autoscaling_group" "web_asg" {

  name = "terraform-web-asg"                             # Auto Scaling Group ka naam.

  min_size         = 2                                    # Chahe traffic kitna bhi kam ho, minimum 2 EC2 instances hamesha running rahengi (high availability ke liye).
  max_size         = 5                                    # Traffic badhne par bhi ASG maximum 5 instances tak hi scale karega, cost control ke liye.
  desired_capacity = 3                                    # Shuruaat me (jab ASG create hoga) ye 3 EC2 instances launch karega.

  vpc_zone_identifier = data.aws_subnets.default.ids       # Ye batata hai ki ASG kin-kin subnets (Availability Zones) me naye EC2 instances launch kar sakta hai.
  # Multiple subnets dene se instances alag-alag AZ me distribute ho jaate hain, jisse ek AZ down hone par bhi service chalti rahe.

  target_group_arns = [aws_lb_target_group.web_tg.arn]     # ASG se launch hone wali har EC2 automatically is Target Group me register ho jayegi,
  # taaki ALB unhe turant traffic bhejna shuru kar de, manually register karne ki zaroorat nahi.

  health_check_type         = "ELB"                       # Health check ka source "ELB" set kiya hai, matlab ASG instance ki health khud check karne ke bajaye ALB 
                                                           ke health check result pe depend karega — ye EC2's own health 
														   check se zyada accurate hota hai kyunki application-level check hota hai.
  health_check_grace_period = 120                          # Naya instance launch hone ke baad 120 second ka grace period diya gaya hai,
                                                             taaki boot + Nginx start hone ka time mil jaye before health check start ho.

  launch_template {

    id      = aws_launch_template.web_lt.id                # ASG batata hai ki naye instances banate waqt kaunsa Launch Template blueprint use karna hai.
    version = "$Latest"                                     # "$Latest" ka matlab hai Launch Template ka sabse naya (latest) version hamesha use hoga, chahe future me template update ho jaye.
  }

  tag {
    key                 = "Name"                            # Tag ka key "Name" rakha gaya hai.
    value               = "ASG-Web-Server"                   # Tag ki value — har naya instance is naam se dikhega.
    propagate_at_launch = true                               # true ka matlab hai ye tag ASG se launch hone wale har naye EC2 instance pe automatically copy ho jayega.
  }
}

############################################################
# Auto Scaling Policy (CPU Based Scale Out)
############################################################

resource "aws_autoscaling_policy" "cpu_scale_out" {

  name                   = "cpu-scale-out"                 # Policy ka naam — ye specifically "scale out" (instances badhane) ke liye hai.
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  # Ye policy batati hai ki ye kis Auto Scaling Group pe apply hogi.

  adjustment_type        = "ChangeInCapacity"               # Ye batata hai ki scaling_adjustment ki value ko kaise interpret karna hai — "ChangeInCapacity" matlab ek fixed number add/remove karega.
  scaling_adjustment     = 1                                # Jab bhi ye policy trigger hogi, ASG me 1 naya EC2 instance add ho jayega.
  cooldown               = 300                              # Ek scaling action ke baad 300 second (5 min) tak koi aur scaling action nahi hoga, taaki system stabilize ho sake aur bar-bar scale na ho.
}

############################################################
# CloudWatch Alarm (Scale Out)
############################################################

resource "aws_cloudwatch_metric_alarm" "high_cpu" {

  alarm_name          = "high-cpu-alarm"                    # Alarm ka naam, monitoring ke liye AWS Console me dikhega.
  comparison_operator = "GreaterThanThreshold"               # Alarm tab trigger hoga jab metric ki value diye gaye threshold se zyada ho jaye.
  evaluation_periods  = 2                                    # Lagatar 2 periods tak condition true rehni chahiye, tabhi alarm officially "ALARM" state me jayega (false alarms avoid karne ke liye).
  metric_name         = "CPUUtilization"                    # Ye alarm EC2 ke CPU usage (%) ko monitor karta hai.
  namespace           = "AWS/EC2"                            # Ye batata hai ki metric kaunsi AWS service (yahan EC2) se related hai.
  period              = 120                                  # Har 120 second (2 min) ke interval me metric ki value check hogi.
  statistic           = "Average"                            # Us period ke andar CPU ka average value liya jayega (min/max/sum ke bajaye).

  threshold = 70                                             # Agar Average CPU Utilization 70% se upar chala jaye to alarm trigger hoga.

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
    # Dimensions batate hain ki ye alarm specifically kis resource (yahan hamare ASG) ke metrics track karega, poore AWS account ke nahi.
  }

  alarm_actions = [aws_autoscaling_policy.cpu_scale_out.arn]
  # Jaise hi alarm "ALARM" state me jayega (CPU > 70%), ye automatically upar wali Scale-Out Policy ko execute kar dega, jisse ek naya EC2 add ho jayega.
}

############################################################
# Outputs
############################################################

output "alb_dns_name" {
  value = aws_lb.alb.dns_name                              # Ye ALB ka public DNS name print karega — isi URL ko browser me khol kar website test ki ja sakti hai.
}

output "launch_template_id" {
  value = aws_launch_template.web_lt.id                     # Launch Template ka unique ID output me milega, reference/debugging ke liye useful hai.
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.web_asg.name                # Auto Scaling Group ka naam output me print hoga.
}

output "target_group_arn" {
  value = aws_lb_target_group.web_tg.arn                    # Target Group ka ARN (Amazon Resource Name) print hoga, jo dusre resources me reference karne ke kaam aata hai.
}





--------------------------------------------------------------------------------------------------------------------------------------------------




############################################################
# 21. Create S3 Bucket
############################################################

resource "aws_s3_bucket" "app_bucket" {
  bucket = "terraform-demo-app-bucket-9981"                # S3 bucket name GLOBALLY unique hona chahiye, isliye unique suffix (9981) add kiya.

  tags = {
    Name = "terraform-demo-app-bucket"                       # AWS Console me is bucket ka display naam is tag se dikhega.
  }
}

############################################################
# 22. Enable Versioning on S3 Bucket
############################################################

resource "aws_s3_bucket_versioning" "app_bucket_versioning" {
  bucket = aws_s3_bucket.app_bucket.id                       # Versioning ko upar wale bucket ke saath link kar rahe hain.

  versioning_configuration {
    status = "Enabled"                                        # Enabled karne se bucket har object ki multiple versions store karega, accidental delete/overwrite se protection milegi.
  }
}

############################################################
# 23. Create IAM Role for EC2
############################################################

resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-access-role"                                 # IAM Role ka naam, jo EC2 instance ko assign kiya jayega.

  assume_role_policy = jsonencode({
    Version = "2012-10-17"                                    # IAM policy language ka fixed standard version date hai jo AWS expect karta hai.
    Statement = [
      {
        Action    = "sts:AssumeRole"                          # Ye action define karta hai ki koi service is role ko "assume" (use) kar sakti hai.
        Effect    = "Allow"                                    # Is action ko explicitly allow kar rahe hain.
        Principal = {
          Service = "ec2.amazonaws.com"                        # Sirf EC2 service hi is role ko assume kar sakti hai, koi aur user/service nahi.
        }
      }
    ]
  })                                                            # jsonencode() HCL block ko JSON string me convert karta hai kyunki IAM policies JSON format me hoti hain.

  tags = {
    Name = "ec2-s3-access-role"                                 # Console me role ka naam is tag se dikhega.
  }
}

############################################################
# 24. Attach IAM Policy to EC2 Role
############################################################

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "ec2-s3-access-policy"                                # Is inline policy ka naam.
  role = aws_iam_role.ec2_s3_role.id                            # Ye policy directly upar wale IAM Role ke saath attach ho rahi hai.

  policy = jsonencode({
    Version = "2012-10-17"                                      # Policy language ka standard version format.
    Statement = [
      {
        Effect = "Allow"                                        # Neeche di gayi actions ko allow kar rahe hain.
        Action = [
          "s3:GetObject",                                        # EC2 ko S3 se files READ (download) karne ki permission.
          "s3:PutObject",                                        # EC2 ko S3 me naye objects UPLOAD karne ki permission.
          "s3:ListBucket"                                        # EC2 ko bucket ke andar files LIST karne ki permission.
        ]
        Resource = [
          aws_s3_bucket.app_bucket.arn,                          # Bucket-level operations (jaise ListBucket) ke liye ye ARN chahiye.
          "${aws_s3_bucket.app_bucket.arn}/*"                    # "/*" wildcard bucket ke andar ke saare objects ke liye permission deta hai.
        ]
      }
    ]
  })                                                              # Least-privilege: poori S3 access (s3:*) ke bajaye sirf 3 zaroori actions diye hain.
}

############################################################
# IAM Instance Profile (Role ko EC2 se attach karne ka bridge)
############################################################

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-instance-profile"                              # Instance Profile ka naam.
  role = aws_iam_role.ec2_s3_role.name                           # Upar wale IAM Role ko is Instance Profile ke saath link kiya, EC2 role ko sirf isi profile ke through use karta hai.
}

############################################################
# 25. Access S3 from EC2 using IAM Role
############################################################

data "aws_ami" "ubuntu" {
  most_recent = true                                            # Latest available Ubuntu AMI automatically select hogi.
  owners      = ["099720109477"]                                # Canonical (Ubuntu ka official publisher) ka verified AWS Account ID.

  filter {
    name   = "name"                                             # AMI name ke basis pe filter laga rahe hain.
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]  # Sirf Ubuntu 24.04 GP3 SSD server images match hongi.
  }
}

resource "aws_instance" "s3_access_ec2" {
  ami           = data.aws_ami.ubuntu.id                        # Upar fetch ki gayi latest Ubuntu AMI use hogi.
  instance_type = "t2.micro"                                    # Free-tier eligible chhota instance type.
  key_name      = "terraform-01"                                # Pehle se bana hua SSH Key Pair, EC2 login ke liye.

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name  # Isi line se EC2 ko IAM Role ke permissions milte hain, bina access key/secret key ke.

  user_data = <<-EOF
#!/bin/bash
apt-get update -y                                                     # System packages update kar rahe hain.
apt-get install awscli -y                                             # AWS CLI install kar rahe hain taaki S3 commands chal sakein.
echo "Testing S3 access using IAM Role" > /home/ubuntu/test.txt       # Upload karne ke liye ek test file bana rahe hain.
aws s3 cp /home/ubuntu/test.txt s3://${aws_s3_bucket.app_bucket.bucket}/test.txt   # File ko S3 bucket me upload kar rahe hain, IAM Role ke temporary credentials se.
aws s3 ls s3://${aws_s3_bucket.app_bucket.bucket}/ >> /home/ubuntu/test.txt        # Bucket ki files list karke test.txt me append kar rahe hain, access verify karne ke liye.
EOF

  tags = {
    Name = "EC2-S3-IAM-Access"                                   # AWS Console me is EC2 instance ka naam.
  }
}

############################################################
# Outputs
############################################################

output "s3_bucket_name" {
  value = aws_s3_bucket.app_bucket.bucket                        # S3 bucket ka naam print karega.
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.app_bucket.arn                            # S3 bucket ka ARN print karega.
}

output "iam_role_name" {
  value = aws_iam_role.ec2_s3_role.name                           # IAM Role ka naam output me milega.
}

output "ec2_instance_id" {
  value = aws_instance.s3_access_ec2.id                           # EC2 instance ki unique ID print hogi.
}

output "ec2_public_ip" {
  value = aws_instance.s3_access_ec2.public_ip                    # EC2 ka public IP, SSH login ke liye.
}




--------------------------------------------------------------------------------------------------------------------------------------------------




############################################################
# 8. IAM Role + IAM Policy
############################################################

resource "aws_iam_role" "app_role" {
  name = "terraform-app-role"                                   # IAM Role ka naam, jo kisi bhi AWS service (EC2/Lambda etc.) ko assign kiya ja sakta hai.

  assume_role_policy = jsonencode({
    Version = "2012-10-17"                                      # IAM policy language ka fixed standard version date, AWS isi format ko expect karta hai.
    Statement = [
      {
        Action    = "sts:AssumeRole"                            # Ye permission define karti hai ki koi service is role ko "assume" (use) kar sakti hai.
        Effect    = "Allow"                                      # Is action ko explicitly allow kar rahe hain.
        Principal = {
          Service = "ec2.amazonaws.com"                          # Sirf EC2 service hi is role ko assume kar sakti hai, koi aur service/user nahi.
        }
      }
    ]
  })                                                              # Ye "Trust Policy" hai — batati hai KAUN role use kar sakta hai, ye nahi batati role kya kar sakta hai.

  tags = {
    Name = "terraform-app-role"                                   # AWS Console me role ka naam is tag se dikhega.
  }
}

resource "aws_iam_policy" "app_policy" {
  name        = "terraform-app-policy"                           # Standalone IAM Policy ka naam (inline policy nahi, reusable managed policy hai).
  description = "Custom policy for application role"              # Policy ka purpose documentation ke liye.

  policy = jsonencode({
    Version = "2012-10-17"                                        # Policy language ka standard version format.
    Statement = [
      {
        Effect   = "Allow"                                        # Neeche di gayi actions ko allow kar rahe hain.
        Action   = [
          "s3:GetObject",                                          # S3 se files read karne ki permission.
          "s3:PutObject",                                          # S3 me files upload karne ki permission.
          "s3:ListBucket"                                          # S3 bucket ke andar files list karne ki permission.
        ]
        Resource = ["*"]                                           # "*" ka matlab hai ye permission sabhi S3 resources pe apply hogi (production me specific bucket ARN dena better practice hai).
      },
      {
        Effect   = "Allow"                                         # Doosra statement, alag set of permissions ke liye.
        Action   = [
          "logs:CreateLogGroup",                                   # CloudWatch me naya log group banane ki permission.
          "logs:CreateLogStream",                                  # Log group ke andar naya log stream banane ki permission.
          "logs:PutLogEvents"                                      # Actual log entries bhejne ki permission.
        ]
        Resource = ["*"]                                            # Ye logging permissions bhi sabhi log groups pe apply hongi.
      }
    ]
  })                                                                 # Ye "Permission Policy" hai — role assume karne ke baad kya actions allowed hain, wo yahan define hota hai.
}

resource "aws_iam_role_policy_attachment" "app_role_attach" {
  role       = aws_iam_role.app_role.name                          # Ye batata hai ki policy kis role ke saath attach ho rahi hai.
  policy_arn = aws_iam_policy.app_policy.arn                        # Upar wali standalone (managed) policy ka ARN attach kiya ja raha hai role ke saath.
  # Note: "aws_iam_role_policy" (inline) ke bajaye yahan "aws_iam_role_policy_attachment" use kiya hai kyunki policy ek reusable, standalone resource hai jo multiple roles pe attach ho sakti hai.
}

resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "terraform-app-instance-profile"                          # Instance Profile ka naam.
  role = aws_iam_role.app_role.name                                 # Role ko Instance Profile ke saath link kar rahe hain, taaki EC2 isko use kar sake.
}

############################################################
# 9. S3 Backend + DynamoDB State Locking
############################################################

# ------------------------------------------------------------
# Step 1: Backend ke liye S3 Bucket aur DynamoDB Table banana
# ------------------------------------------------------------
# Important: Backend resources (S3 bucket + DynamoDB table) ko usi Terraform config se
# nahi bana sakte jisme unhe backend ke taur pe use karna hai (chicken-and-egg problem),
# isliye ye resources pehle ek ALAG/bootstrap Terraform run me (local backend ke saath) create karte hain.

resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-bucket-9981"                          # State file store karne wala bucket, naam globally unique hona chahiye.

  lifecycle {
    prevent_destroy = true                                          # Ye safety guard hai — accidentally is bucket ko destroy hone se rokta hai (isme poora state history hota hai).
  }

  tags = {
    Name = "terraform-state-bucket"                                  # Console me bucket ka naam.
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id                         # Versioning ko state bucket ke saath link kar rahe hain.

  versioning_configuration {
    status = "Enabled"                                               # State file ki purani versions bhi preserve rahengi, galti se corrupt/overwrite hone par recover ki ja sakti hain.
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id                          # Encryption config ko state bucket ke saath link kar rahe hain.

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"                                        # State file ke andar sensitive data (jaise secrets/IDs) ho sakta hai, isliye encryption at rest enable kar rahe hain.
    }
  }
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-state-lock"                              # DynamoDB table ka naam, backend config me isi naam se reference hoga.
  billing_mode = "PAY_PER_REQUEST"                                    # Fixed capacity plan karne ke bajaye, jitna use utna bill — locking table 
                                                                       ke liye ideal hai kyunki traffic kam/unpredictable hota hai.
  hash_key     = "LockID"                                             # DynamoDB me primary key ka naam "LockID" hona MANDATORY hai —
                                                                          Terraform yahi key name expect karta hai locking ke liye.

  attribute {
    name = "LockID"                                                    # Attribute define kar rahe hain jo hash_key me reference hua hai.
    type = "S"                                                          # "S" ka matlab String type hai.
  }

  tags = {
    Name = "terraform-state-lock"                                       # Console me table ka naam.
  }
}

# ------------------------------------------------------------
# Step 2: Backend Configuration (isi project ke terraform block me daalna)
# ------------------------------------------------------------
# Note: Ye block upar wale S3 bucket/DynamoDB table create hone ke BAAD, ek naye/existing
# terraform { } block ke andar add hota hai — isko "terraform init" karke migrate karna padta hai.

# terraform {
#   backend "s3" {
#     bucket         = "terraform-state-bucket-9981"                  # Wahi bucket jo upar bana hai, state file yahan store hogi.
#     key            = "project/terraform.tfstate"                    # State file ka path/name bucket ke andar.
#     region         = "ap-south-1"                                    # Bucket jis region me hai.
#     dynamodb_table = "terraform-state-lock"                          # Locking ke liye wahi DynamoDB table use hogi.
#     encrypt        = true                                             # State file S3 me encrypted store hogi.
#   }
# }
# Locking ka fayda: Jab ek user "terraform apply" chala raha ho, tab DynamoDB me ek lock entry ban jaati hai —
# isse dusra user/CI-pipeline simultaneously apply nahi chala sakta, jo state file corruption/conflict se bachata hai.

############################################################
# Outputs
############################################################

output "iam_role_arn" {
  value = aws_iam_role.app_role.arn                                   # IAM Role ka ARN print karega.
}

output "iam_policy_arn" {
  value = aws_iam_policy.app_policy.arn                                # IAM Policy ka ARN print karega.
}

output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket                         # State store karne wale S3 bucket ka naam print karega.
}

output "dynamodb_lock_table_name" {
  value = aws_dynamodb_table.terraform_lock.name                       # Locking ke liye DynamoDB table ka naam print karega.
}




----------------------------------------------------------------------------------------------------------------------------------------------



Chalo, ekdum deep me Hinglish mein samajhte hain ki Terraform internally kaam kaise karta hai, 
aur uske baad saare important Terraform commands bhi explain karta hoon.

## Terraform Internally Kaam Kaise Karta Hai

**1. Terraform Core aur Provider — Do Alag Parts**

Terraform ek single tool nahi hai, ye do hisson mein divide hota hai:

- **Terraform Core (Engine)**: Ye tumhari `.tf` files ko read karta hai, 
HCL (HashiCorp Configuration Language) ko parse karta hai, aur ek internal **dependency graph** banata hai. Ye engine khud AWS se baat nahi karta.
- **Provider (Plugin)**: Jab tum `terraform init` chalate ho, 
to Terraform `hashicorp/aws` provider ka binary download karke `.terraform/` folder mein 
rakh deta hai. Ye provider basically ek translator hai — ye janta hai ki `aws_instance` 
resource likhne ka matlab hai AWS ke `RunInstances` API call karna, `aws_s3_bucket` likhne ka matlab hai `CreateBucket` API call karna.

Isliye jab tum `resource "aws_instance" "web" {}"` likhte ho, 
tab kuch bhi create nahi hota — tum sirf apna **desired state** (tumhe kya chahiye) 
describe kar rahe ho. Real cheez API call apply karne pe hoti hai.

**2. Console Se Direct Connection Nahi Hota**

Ye important point hai — Terraform kabhi AWS Console se baat nahi karta. AWS Console 
khud ek website hai jo AWS ke backend database se data read karke dikhati hai. 
Terraform seedha **AWS API** (jo Console bhi use karta hai) ko call karta hai 
apne credentials (Access Key/Secret Key ya IAM Role) ke through. Jab AWS pe 
resource create/delete ho jata hai, to Console usko automatically reflect kar deta hai kyunki dono same backend se data read kar rahe hain.

**3. State File — Terraform Ki "Memory"**

Ye sabse important internal cheez hai. Jab bhi tum `apply` karte ho, Terraform 
ek file banata hai — `terraform.tfstate` — ye ek JSON file hai jo har resource ka real-world mapping store karti hai:

- Tumhare code ka block (jaise `aws_instance.web`) 
- Us block se corresponding real AWS resource ki ID, IP, ARN, current configuration

Har baar jab tum `plan` ya `apply` chalate ho, Terraform ye 3 steps follow karta hai:

1. **Refresh** — AWS se real-time status check karta hai (kya resource abhi bhi exist karta hai, kuch manually change to nahi hua).
2. **Compare** — State file, tumhari `.tf` code, aur real AWS world — teeno ko compare karta hai.
3. **Diff Calculate** — Pata karta hai ki minimum kitne changes chahiye AWS ko tumhare code jaisa banane ke liye.

Agar state file na ho, to Terraform ko pata hi nahi chalega ki `aws_instance.web` 
naam ka resource pehle se AWS pe exist karta hai ya nahi — har baar naya resource 
bana dega (duplicate ho jayega). Isliye state file ko kabhi manually edit ya delete nahi karna chahiye.

**4. Dependency Graph (DAG)**

Terraform tumhare saare resources ke beech ke references dekh kar ek **Directed Acyclic Graph** banata 
hai. Jaise agar `aws_instance` resource ke andar `aws_security_group.sg.id` reference hai, to 
Terraform samajh jata hai ki pehle Security Group banna chahiye, uske baad EC2. 

Is graph ka fayda:
- Sahi order mein resources create honge (VPC → Subnet → Security Group → EC2), reverse order mein nahi.
- Jo resources ek dusre pe depend nahi karte, wo **parallel** mein create ho sakte hain (speed fast ho jati hai).
- Destroy karte waqt Terraform isi graph ko **reverse** kar deta hai — pehle EC2 delete hoga, uske baad Security Group.

**5. Apply Kaise Hota Hai (Step by Step)**

Jab tum `terraform apply` chalate ho:

1. Terraform pehle `plan` wala calculation dobara karta hai.
2. Provider (AWS plugin) ko actual API calls bhejta hai — jaise `ec2:RunInstances`.
3. AWS response deta hai (Instance ID, Public IP, ARN waghera).
4. Terraform ye saari values state file mein save kar deta hai.
5. AWS Console automatically nayi resource dikhane lag jata hai, kyunki wo bhi same AWS backend se read kar raha hai.

**6. Destroy Kaise Hota Hai**

`terraform destroy` state file padhta hai, wahi dependency graph banata hai, usko **reverse** karta hai, 
aur har resource ke liye provider ka delete API call karta hai (jaise `ec2:TerminateInstances`, `s3:DeleteBucket`). AWS 
confirm karta hai deletion, aur Terraform us entry ko state file se bhi hata deta hai.

--------------------------------------------------------------------------------------------------------------------------------

## Saare Important Terraform Commands (Detailed)

**`terraform init`**
Sabse pehla command, kisi bhi naye project mein ek baar chalana zaroori hai. Ye 3 kaam 
karta hai: (1) `required_providers` block dekh kar AWS provider plugin download karta hai `.terraform/` folder mein,
 (2) `backend` config check karta hai (state kahan store hogi — local ya S3), (3) agar modules use kiye hain to
 unhe bhi download karta hai. Jab bhi backend ya provider version change karo, dobara `init` chalana padta hai.

**`terraform validate`**
Sirf syntax check karta hai — tumhari `.tf` files mein koi typo, missing bracket, wrong argument to nahi hai.
 Ye AWS se koi connection nahi banata, sirf local file structure validate karta hai.

**`terraform fmt`**
Code ko automatically properly indent/format kar deta hai (jaise Prettier karta hai JS mein). Team mein 
consistency rakhne ke liye use hota hai.

**`terraform plan`**
Ye "dry-run" hai — batata hai ki agar tum `apply` karo to kya-kya change hoga (kitne resources add/change/destroy honge),
 lekin actually kuch bhi create/delete nahi karta. Sirf read-only API calls karta hai AWS se current status
 check karne ke liye. Hamesha `apply` se pehle `plan` dekhna best practice hai.

**`terraform apply`**
Real resources create/update karta hai AWS pe. Pehle `plan` jaisa diff dikhata hai, phir confirmation (yes/no)
 maangta hai, "yes" karne pe actual API calls chalti hain aur state file update hoti hai. `-auto-approve` flag 
 se confirmation skip ho jati hai (CI/CD pipelines mein use hota hai).

**`terraform destroy`**
State file mein jitne bhi resources track ho rahe hain, sabko AWS se delete kar deta hai, reverse dependency 
order mein. Bahut carefully use karna chahiye — production mein galti se poora infrastructure delete ho sakta hai.

**`terraform show`**
Current state file ko human-readable format mein dikhata hai — kaunse resources exist karte hain, unki current attribute values kya hain.

**`terraform state list`**
State file mein track ho rahe saare resources ki list dikhata hai (jaise `aws_instance.web`, `aws_s3_bucket.app_bucket`).

**`terraform state show <resource>`**
Ek specific resource ki poori detail (saari attributes — ID, ARN, IP, tags) state file se nikal kar dikhata hai.

**`terraform state rm <resource>`**
Kisi resource ko state file se hata deta hai, lekin AWS pe wo resource actually delete NAHI hota. Use case: agar
 tum chahte ho ki Terraform ab us resource ko manage karna band kar de, lekin real AWS resource waisa hi rahe.

**`terraform import`**
Agar koi resource manually AWS Console se banaya gaya tha (Terraform se nahi), to ye command usko state file mein 
add kar deta hai, taaki Terraform ab usko bhi track/manage karna shuru kar de.

**`terraform output`**
`output` blocks mein define ki gayi values (jaise EC2 public IP, S3 bucket ARN) ko print karta hai, bina dobara apply kiye.

**`terraform refresh`** *(ab `plan -refresh-only` recommended hai)*
State file ko real AWS world ke saath sync karta hai — agar kisi ne manually Console se kuch change kar diya, to 
ye state file ko update kar deta hai us change ko reflect karne ke liye.

**`terraform taint`** *(deprecated, ab `terraform apply -replace=<resource>` use hota hai)*
Kisi specific resource ko force-mark karta hai ki agli `apply` pe usko destroy karke dobara naya banaya jaye,
 chahe code mein koi change na ho.

**`terraform workspace`**
Same code se multiple environments (dev, staging, prod) manage karne ke liye — har workspace ki apni alag 
state file hoti hai, lekin code same rehta hai.

**`terraform graph`**
Dependency graph ko visual format (DOT language) mein export karta hai, jise Graphviz jaise tool se image
 bana sakte ho — resources ke beech dependencies visually dekhne ke liye.
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
---------------------------------------------------------------------------------------------------------------------------------------------



############################################################
# main.tf — All Concepts Demo (Interview Prep)
# Ye ek single file hai jisme Terraform ke core concepts +
# important AWS services + security/compliance patterns
# demonstrate kiye gaye hain, sab heavily commented Hinglish mein.
############################################################

terraform {
  required_version = ">= 1.5.0"                                  # Ye batata hai ki minimum kaunsa Terraform CLI version chahiye, 
                                                                 isse behind logic (jaise for_each, optional attributes) sahi chalta hai.

  required_providers {
    aws = {
      source  = "hashicorp/aws"                                    # AWS provider HashiCorp Registry se aayega.
      version = "~> 6.0"                                            # "~>" ka matlab hai 6.x ke andar koi bhi minor/patch version chalega,
                                                                 	  lekin 7.0 pe auto-upgrade nahi hoga.
    }
  }
}

provider "aws" {
  region = "ap-south-1"                                             # Saare resources Mumbai region mein banenge.
}

############################################################
# SECTION A1: Variables, Locals, Data Sources
############################################################

variable "environment" {
  description = "Deployment environment"                            # Ye variable batata hai infra kis environment ke liye hai.
  type        = string                                               # Sirf string value accept karega.
  default     = "dev"                                                 # Agar value na di jaye to "dev" default use hoga.
}

variable "instance_count" {
  description = "Number of EC2 instances to create"                  # count/for_each demo ke liye ye variable use hoga.
  type        = number
  default     = 2
}

variable "subnet_cidrs" {
  description = "Map of subnet names to CIDR blocks"                  # for_each demo ke liye map type variable.
  type        = map(string)
  default = {
    "app"  = "10.0.1.0/24"                                             # Application subnet ka CIDR.
    "data" = "10.0.2.0/24"                                             # Database subnet ka CIDR.
  }
}

locals {
  name_prefix = "${var.environment}-amex-demo"                        # Locals se hum ek common naming convention bana rahe hain,
                                                                        baar baar type nahi karna padega.
  common_tags = {
    Environment = var.environment                                     # Consistent tagging strategy — har resource pe ye tags 
	                                                                   lagenge (Cost Management ke liye important).
    Owner       = "platform-team"
    CostCenter  = "CC-1024"
    ManagedBy   = "terraform"                                          # Ye batata hai ki resource manually nahi, Terraform se bana hai.
  }
}

data "aws_vpc" "default" {
  default = true                                                       # Data source — sirf EXISTING resource ko READ karta hai, naya nahi banata.
}

data "aws_availability_zones" "available" {
  state = "available"                                                  # Region ke saare currently available AZs fetch karega.
}

############################################################
# SECTION A2: count vs for_each Demo
############################################################

# --- count ka example ---
resource "aws_iam_user" "count_demo" {
  count = var.instance_count                                            # count = 2 hai, isliye 2 IAM users banenge: count_demo[0], count_demo[1].
  name  = "${local.name_prefix}-user-${count.index}"                     # Har user ka naam index ke basis pe generate hota hai (user-0, user-1).
  # PROBLEM: Agar beech se ek user hata do (jaise index 0), to Terraform baaki sabko RENAME/RECREATE kar dega,
  # kyunki index shift ho jata hai — ye count ki sabse badi limitation hai.
}

# --- for_each ka example (BETTER approach for named/keyed resources) ---
resource "aws_subnet" "for_each_demo" {
  for_each = var.subnet_cidrs                                            # Map ke har KEY ("app", "data") ke liye ek subnet banega.

  vpc_id            = data.aws_vpc.default.id                            # Default VPC ke andar subnet banega.
  cidr_block        = each.value                                          # each.value = us key ki CIDR value (jaise "10.0.1.0/24").
  availability_zone = data.aws_availability_zones.available.names[0]       # Pehli available AZ use kar rahe hain.

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-subnet"                       # each.key = "app" ya "data", isse naam meaningful banta hai.
  })
  # FAYDA: Agar "app" subnet hata bhi do, to sirf wahi delete hoga, "data" subnet ko koi effect nahi hoga —
  # kyunki identity KEY se track hoti hai, index se nahi. Isliye named resources ke liye for_each better hai.
}

############################################################
# SECTION A3: Lifecycle Meta-Arguments Demo
############################################################

resource "aws_launch_template" "demo_lt" {
  name_prefix   = "${local.name_prefix}-lt-"                              # Launch Template ka naam prefix.
  image_id      = "ami-0abcdef1234567890"                                  # Placeholder AMI ID (real project mein data.aws_ami se aayega).
  instance_type = "t2.micro"

  lifecycle {
    create_before_destroy = true                                          # Naya Launch Template pehle banega, PURANA uske baad delete hoga — isse 
	                                                                       zero-downtime replacement hota hai (ASG rolling update ke waqt useful).
    ignore_changes         = [image_id]                                    # Agar AMI ID AWS side se ya kisi automation se change ho jaye,
                                                                          	Terraform usko "drift" nahi manega, ignore kar dega.
  }
}

resource "aws_s3_bucket" "critical_data" {
  bucket = "${local.name_prefix}-critical-bucket"                          # Critical/production data store karne wala bucket.

  lifecycle {
    prevent_destroy = true                                                  # Safety guard — "terraform destroy" chalane par bhi ye 
	                                                                        bucket accidentally delete NAHI hoga, pehle isko manually hatana padega.
  }

  tags = local.common_tags
}

############################################################
# SECTION A4: Provisioners (local-exec / remote-exec) — DEMO ONLY
############################################################
# NOTE: Terraform docs khud recommend karti hain ki provisioners ko "last resort" ki tarah use karo.
# Configuration management (jaise Ansible, Chef) is kaam ke liye better tools hain, kyunki provisioners
# Terraform ke declarative model ko break karte hain — Terraform ko pata nahi chalta provisioner ke andar kya hua.

resource "null_resource" "provisioner_demo" {
  provisioner "local-exec" {
    command = "echo 'Resource created successfully' >> deployment-log.txt"  # Ye command Terraform CHALANE WALE machine pe local 
	                                                                          run hoti hai, AWS resource ke andar nahi.
  }

  # provisioner "remote-exec" {
  #   inline = ["sudo apt-get update -y"]                                    # Ye AWS resource (jaise EC2) ke ANDAR SSH karke
                                                                                commands chalata, yahan disabled rakha hai demo ke liye.
  # }
}

############################################################
# SECTION A5: Module Usage Example
############################################################
# Real project mein VPC jaisa reusable setup ek child module mein rakha jaata hai,
# aur root module se sirf call kiya jaata hai — isse code duplicate nahi hota multiple environments mein.

# module "vpc" {
#   source  = "./modules/vpc"                                               # Local path se module ko call kar rahe hain (Terraform Registry se bhi ho sakta hai: "terraform-aws-modules/vpc/aws").
#   version = "5.0.0"                                                        # Registry module use karte waqt version pin karna best practice hai.
#
#   name_prefix  = local.name_prefix                                        # Root module se child module ko variables pass ho rahe hain.
#   subnet_cidrs = var.subnet_cidrs
# }
# Child module ke andar apna alag variables.tf, main.tf, outputs.tf hota hai — ye ek self-contained reusable unit hoti hai.

############################################################
# SECTION B1: RDS (Multi-AZ, Private Subnet)
############################################################

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${local.name_prefix}-rds-subnet-group"                     # DB Subnet Group ka naam — RDS ko batata hai ki kin subnets mein deploy ho sakta hai.
  subnet_ids = [for s in aws_subnet.for_each_demo : s.id]                   # For-loop expression se saare for_each subnets ke IDs ek list mein collect kar rahe hain.

  tags = local.common_tags
}

resource "aws_db_instance" "app_db" {
  identifier     = "${local.name_prefix}-db"                                # RDS instance ka unique identifier.
  engine         = "postgres"                                               # Database engine — PostgreSQL use kar rahe hain.
  engine_version = "15.4"
  instance_class = "db.t3.micro"                                            # Chhota instance class, dev/testing ke liye.

  allocated_storage = 20                                                    # 20 GB storage allocate ki hai.
  storage_encrypted = true                                                  # IMPORTANT: Data-at-rest encryption enabled hai — finance company mein ye almost mandatory hota hai.

  db_name  = "appdb"
  username = "dbadmin"
  password = "ChangeMe123!"                                                 # PRODUCTION MEIN YE HARDCODE NAHI KARTE — Section B4 (Secrets Manager) dekho, wahan se fetch karna chahiye.

  multi_az               = true                                             # Multi-AZ deployment — primary DB fail hone par automatically standby DB mein failover hoga, downtime minimize hota hai.
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name         # Ye batata hai RDS kaunse (private) subnets mein launch hogi.
  publicly_accessible    = false                                            # CRITICAL: Database kabhi bhi public internet se directly accessible nahi honi chahiye.
  backup_retention_period = 7                                                # 7 din tak automated backups store honge, point-in-time recovery ke liye.
  skip_final_snapshot    = true                                              # Demo ke liye true rakha hai — production mein false rakhte hain taaki delete se pehle final snapshot ban jaye.

  tags = local.common_tags
}

############################################################
# SECTION B2: Lambda + API Gateway (Serverless)
############################################################

resource "aws_iam_role" "lambda_exec_role" {
  name = "${local.name_prefix}-lambda-role"                                  # Lambda function ko assign hone wala IAM role.

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }                        # Sirf Lambda service hi is role ko assume kar sakti hai.
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec_role.name                             # Lambda role ke saath AWS ki managed policy attach kar rahe hain.
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"  # Ye policy Lambda ko CloudWatch Logs likhne ki basic permission deti hai.
}

resource "aws_lambda_function" "app_function" {
  function_name = "${local.name_prefix}-function"                             # Lambda function ka naam.
  role          = aws_iam_role.lambda_exec_role.arn                            # Upar wala IAM role attach kiya.
  handler       = "index.handler"                                              # Entry point function (file.function_name format).
  runtime       = "nodejs20.x"                                                  # Runtime environment.
  filename      = "lambda_placeholder.zip"                                      # Deployment package — real project mein `archive_file` data source se generate hota hai.

  tags = local.common_tags
}

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${local.name_prefix}-api"                                    # HTTP API Gateway ka naam.
  protocol_type = "HTTP"                                                         # REST API ke bajaye lightweight HTTP API use kar rahe hain (faster + cheaper).
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id                      # Ye integration is API Gateway ke saath link hai.
  integration_type       = "AWS_PROXY"                                            # Proxy integration — poori request directly Lambda ko forward hogi.
  integration_uri        = aws_lambda_function.app_function.invoke_arn            # Kis Lambda function ko call karna hai.
  payload_format_version = "2.0"
}

############################################################
# SECTION B3: KMS (Encryption Key Management)
############################################################

resource "aws_kms_key" "app_key" {
  description             = "KMS key for encrypting app data"                     # Ye key S3/RDS/EBS encryption ke liye use hogi.
  deletion_window_in_days = 10                                                     # Delete request ke baad 10 din ka grace period (accidental deletion se protection).
  enable_key_rotation     = true                                                    # Key automatically har saal rotate hogi — security best practice.

  tags = local.common_tags
}

resource "aws_kms_alias" "app_key_alias" {
  name          = "alias/${local.name_prefix}-key"                                 # Key ko ek human-readable alias diya, raw Key ID yaad rakhne ki zaroorat nahi.
  target_key_id = aws_kms_key.app_key.key_id
}

############################################################
# SECTION B4: Secrets Manager (No Hardcoded Passwords)
############################################################

resource "aws_secretsmanager_secret" "db_password" {
  name       = "${local.name_prefix}-db-password"                                  # Secret ka naam.
  kms_key_id = aws_kms_key.app_key.arn                                             # Upar wali KMS key se ye secret encrypt hogi.

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password_value" {
  secret_id     = aws_secretsmanager_secret.db_password.id                          # Kis secret ke andar value store karni hai.
  secret_string = jsonencode({ username = "dbadmin", password = "ChangeMe123!" })    # Actual secret value — production mein ye CI/CD pipeline variable se aayegi, code mein hardcoded nahi hogi.
}
# Application code mein hum ye password seedha nahi likhte — Lambda/EC2 runtime pe "aws_secretsmanager_secret_version"
# data source se FETCH karte hain, isse secret kabhi Git repo mein commit nahi hoti.

############################################################
# SECTION B5: Route53 (DNS + Health Check)
############################################################

resource "aws_route53_zone" "app_zone" {
  name = "example-demo.com"                                                          # DNS hosted zone ka naam (domain).

  tags = local.common_tags
}

resource "aws_route53_health_check" "app_health" {
  fqdn              = "app.example-demo.com"                                          # Ye domain periodically health-check hoga.
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"                                                        # Health check endpoint path.
  failure_threshold = 3                                                                 # Lagatar 3 failures ke baad "unhealthy" mark hoga.
  request_interval  = 30                                                                # Har 30 second mein check hoga.
}

resource "aws_route53_record" "app_record" {
  zone_id = aws_route53_zone.app_zone.zone_id                                          # Ye record kis hosted zone ke andar banega.
  name    = "app.example-demo.com"
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"                                                                    # Failover routing — agar primary unhealthy ho jaye to secondary record pe traffic switch ho jayega.
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.app_health.id                              # Upar wale health check se link kiya.

  alias {
    name                   = "dummy-alb-dns-name.ap-south-1.elb.amazonaws.com"           # Real project mein ALB ka actual DNS name yahan reference hota hai.
    zone_id                = "Z35SXDOTRQ7X7K"                                            # ALB ka hosted zone ID (AWS region-specific fixed value).
    evaluate_target_health = true                                                         # Route53 khud ALB ki health dekhega traffic bhejne se pehle.
  }
}

############################################################
# SECTION B6: CloudFront + S3 (Static Content Delivery)
############################################################

resource "aws_s3_bucket" "static_site" {
  bucket = "${local.name_prefix}-static-site"                                            # Static website files (HTML/CSS/JS) store karne wala bucket.
  tags   = local.common_tags
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.name_prefix}-oac"                          # OAC — S3 bucket ko PUBLIC kiye bina CloudFront ko access dene ka secure tareeka.
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true                                                               # CDN distribution enable kar rahe hain.
  default_root_object = "index.html"                                                       # Root URL hit hone par ye file serve hogi.

  origin {
    domain_name              = aws_s3_bucket.static_site.bucket_regional_domain_name        # CloudFront ka origin (source) — S3 bucket.
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id                   # OAC attach kiya, taaki sirf CloudFront hi bucket access kar sake, direct public access nahi.
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]                                                 # Sirf read-only methods allow hain (static content ke liye).
    cached_methods          = ["GET", "HEAD"]
    target_origin_id        = "s3-origin"
    viewer_protocol_policy  = "redirect-to-https"                                             # HTTP request automatically HTTPS pe redirect hogi — encryption in transit.

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }                                             # Koi geographic restriction nahi lagayi (chahe to specific countries block kar sakte hain).
  }

  viewer_certificate {
    cloudfront_default_certificate = true                                                      # Demo ke liye CloudFront ka default SSL certificate use kar rahe hain.
  }

  tags = local.common_tags
}

############################################################
# SECTION B7: WAF (Web Application Firewall)
############################################################

resource "aws_wafv2_web_acl" "app_waf" {
  name  = "${local.name_prefix}-waf"                                                         # WAF Web ACL ka naam.
  scope = "REGIONAL"                                                                           # REGIONAL scope ALB ke liye, "CLOUDFRONT" scope CDN ke liye use hota.

  default_action {
    allow {}                                                                                    # Default behavior: koi rule match na ho to traffic allow karo.
  }

  rule {
    name     = "AWS-Common-Rule-Set"                                                            # AWS ka managed rule group use kar rahe hain (SQL injection, XSS jaise common attacks ke against).
    priority = 1

    override_action { none {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"                                             # AWS ka pre-built security rule set.
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true                                                           # Is rule ke metrics CloudWatch mein bhi track honge.
      metric_name                 = "CommonRuleSetMetric"
      sampled_requests_enabled    = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                 = "${local.name_prefix}-waf-metric"
    sampled_requests_enabled    = true
  }

  tags = local.common_tags
}
# Isko ALB ke saath jodne ke liye "aws_wafv2_web_acl_association" resource use hota hai (resource_arn = ALB ARN, web_acl_arn = is WAF ka ARN).

############################################################
# SECTION C1: CloudTrail (Auditing) + GuardDuty (Threat Detection)
############################################################

resource "aws_cloudtrail" "account_trail" {
  name                          = "${local.name_prefix}-trail"                                  # CloudTrail ka naam.
  s3_bucket_name                = aws_s3_bucket.critical_data.id                                   # Trail logs isi S3 bucket mein store honge (audit evidence).
  include_global_service_events = true                                                             # IAM jaisi global services (jo region-specific nahi hain) ke events bhi capture honge.
  is_multi_region_trail         = true                                                              # Poore AWS account ke saare regions ki activity track hogi, sirf ek region ki nahi.
  enable_log_file_validation    = true                                                               # Log files ki integrity verify karne ke liye digital signature enable — tampering detect ho sakti hai.

  tags = local.common_tags
}

resource "aws_guardduty_detector" "main" {
  enable = true                                                                   # GuardDuty enable karte hi ye automatically account ke logs (VPC Flow Logs, DNS logs, CloudTrail)
                                                                                   analyze karke malicious activity detect karna start kar deta hai.

  tags = local.common_tags
}

############################################################
# SECTION D1: SNS + CloudWatch (Alerting)
############################################################

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"                                                                 # Notification bhejne ke liye SNS topic.
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn                                                                  # Is topic pe koi bhi alert publish hote hi subscriber ko notify hoga.
  protocol  = "email"                                                                                    # Email ke through notify karega (Slack ke liye "https" protocol + webhook URL use hota).
  endpoint  = "devops-team@example-demo.com"                                                              # Notification kis email pe jayegi.
}

resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "${local.name_prefix}-rds-cpu-alarm"                                              # Alarm ka naam.
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"                                                                          # Ye alarm RDS database ke CPU ko monitor kar raha hai.
  period              = 120
  statistic           = "Average"
  threshold           = 80                                                                                  # 80% se zyada CPU hone par trigger hoga.

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.app_db.id                                                        # Specifically isi RDS instance ke metrics track honge.
  }

  alarm_actions = [aws_sns_topic.alerts.arn]                                                                 # Alarm trigger hote hi SNS topic ko notify karega, jo aage email bhej dega.
}

############################################################
# NOTE: In-Code Se NAHI Ban Sakte Concepts (Conceptual Only)
############################################################
# Neeche diye gaye topics ko Terraform "resource" block se directly nahi banaya jata —
# ye tools/platform-level features hain jo Terraform Cloud/Enterprise ya external tools use karte hain:
#
# - Sentinel / OPA (Policy-as-Code): Terraform Cloud/Enterprise ke "Sentinel Policy" ya
#   standalone OPA tool ke through configure hota hai — ye "apply" se PEHLE hi non-compliant
#   resources (jaise public S3 bucket) ko block kar deta hai. Isko ek alag ".sentinel" file mein likhte hain, .tf mein nahi.
#
# - Terraform Cloud/Enterprise (TFC/TFE): Remote execution environment hai — iska setup Terraform
#   Cloud ki website/API se hota hai, isliye single .tf resource block se nahi banta.
#
# - CI/CD Pipeline Integration: Jenkinsfile / GitHub Actions YAML mein likha jata hai (.tf file ke bahar),
#   jisme "terraform plan" PR pe chalta hai aur "terraform apply" manual approval ke baad.
#
# - Blue-Green/Canary Deployment: Ye ek DEPLOYMENT STRATEGY hai, jo aws_autoscaling_group ke
#   "instance_refresh" block (jo humne pehle dekha tha) aur ALB weighted target groups ke
#   combination se implement hoti hai — koi single standalone resource nahi hai.
#
# - EKS + IRSA: Bahut bada setup hai (cluster, node groups, OIDC provider) — agar chahiye to
#   isko separate file mein detail se bana sakte hain.

############################################################
# Outputs
############################################################

output "rds_endpoint" {
  value = aws_db_instance.app_db.endpoint                                                                   # RDS ka connection endpoint print karega.
}

output "lambda_function_arn" {
  value = aws_lambda_function.app_function.arn                                                               # Lambda function ka ARN print karega.
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.cdn.domain_name                                                        # CloudFront distribution ka public domain print karega.
}

output "kms_key_arn" {
  value = aws_kms_key.app_key.arn                                                                             # KMS key ka ARN print karega.
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn                                                                             # SNS alert topic ka ARN print karega.
}
 
 