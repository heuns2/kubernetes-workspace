provider "aws" {
  region = "us-east-2"
}

locals {
  vpc_name        = "test-vpc"
  cidr            = "10.0.0.0/16"
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
  azs             = ["us-east-2a", "us-east-2c"]
  asg_manifests = [for data in split("---", replace("${file("cluster_autoscaler.yaml")}", "<CLUSTER_NAME>", "${var.cluster_name}")): yamldecode(data)]
}

# VPC를 생성
resource "aws_vpc" "this" {
  cidr_block = local.cidr
  tags       = { Name = local.vpc_name }
}

# 퍼플릭 서브넷에 연결할 인터넷 게이트웨이를 생성
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.vpc_name}-igw" }
}

# 퍼플릭 서브넷에 적용할 라우팅 테이블 생성
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.vpc_name}-public" }
}

# 퍼플릭 서브넷 인터넷 게이트웨이 설정
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# 퍼플릭 서브넷을 정의
resource "aws_subnet" "public" {
  count = length(local.public_subnets)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.vpc_name}-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# 퍼플릭 서브넷을 라우팅 테이블에 연결
resource "aws_route_table_association" "public" {
  count = length(local.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT 게이트웨이 용 Elastics IP 생성
resource "aws_eip" "nat_gateway" {
  vpc  = true
  tags = { Name = "${local.vpc_name}-natgw" }
}

# 프라이빗 서브넷에서 인터넷 접속시 사용할 NAT 게이트웨이
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${local.vpc_name}-natgw" }
}

# 프라이빗 서브넷에 적용할 라우팅 테이블
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.vpc_name}-private" }
}

# 프라이빗 서브넷, NAT 게이트웨이 설정
resource "aws_route" "private_worldwide" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

# 프라이빗 서브넷을 정의
resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags = {
    Name = "${local.vpc_name}-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

# 프라이빗 서브넷을 라우팅 테이블에 연결
resource "aws_route_table_association" "private" {
  count = length(local.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Worker Node 보안 그룹 생성
module "all_worker_management" {
  source = "terraform-aws-modules/security-group/aws"
  name   = "all_worker_management"
  vpc_id = aws_vpc.this.id
  ingress_with_cidr_blocks = [
    {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port = 80
      to_port = 80
      protocol = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port = 0
      to_port = 65535
      protocol = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  tags = { "Name": "all_worker_management" }

}

# Worker Node 접속 Key Pair 정의
resource "tls_private_key" "this" {
  algorithm = "RSA"
}

module "key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  key_name   = "test-key-pair"
  public_key = tls_private_key.this.public_key_openssh
  tags = { "Name" = "test-key-pair" }
  
}

resource "local_file" "pem" {
  filename = "${path.root}/test-key-pair.pem"
  content = tls_private_key.this.private_key_pem
  depends_on = [module.key_pair]
}

# Bastion VM Elastic IP 정의
resource "aws_eip" "bastion_2a" {
  instance = module.ec2_instance.id
  vpc = true
  tags = {
      "Name" = "eip-test-bastion"
    }
}
