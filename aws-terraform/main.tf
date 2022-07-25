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



# kubernetes 정의 (kubernetes_config_map.aws_auth)
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}


# Infra를 EKS 정의
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.24.0"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  subnets         = aws_subnet.private[*].id

  vpc_id = aws_vpc.this.id

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  attach_worker_cni_policy = true
  wait_for_cluster_timeout = 600

  node_groups_defaults = {
    root_volume_type = "gp2"
  }

  node_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = "t2.medium"
      additional_userdata           = "echo test 1234"
      additional_security_group_ids = [module.all_worker_management.security_group_id]
      asg_desired_capacity          = 1
      key_name     = module.key_pair.key_pair_name
    }
  ]
}

# VPC CNI 리소스 설정
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = var.cluster_name
  addon_name = "vpc-cni"
  depends_on = [
    module.eks
  ]
}

# Kube Proxy 리소스 설정
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = var.cluster_name
  addon_name = "kube-proxy"
  depends_on = [
    module.eks
  ]
}

# Core DNS 리소스 설정
resource "aws_eks_addon" "coredns" {
  cluster_name = var.cluster_name
  addon_name = "coredns"
  depends_on = [
    module.eks
  ]
}

# EKS Cluster 관련 IAM Role 설정
data "tls_certificate" "cluster" {
  url = module.eks.cluster_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = concat([data.tls_certificate.cluster.certificates.0.sha1_fingerprint], [])
  url = module.eks.cluster_oidc_issuer_url
}

resource "aws_iam_role" "cluster_autoscaler" {
  name = "AmazonEKSClusterAutoscalerRole-test"
  assume_role_policy = templatefile("oidc_assume_role_policy.json", {
    OIDC_ARN = aws_iam_openid_connect_provider.cluster.arn, 
    OIDC_URL = replace(aws_iam_openid_connect_provider.cluster.url, "https://", ""), 
    NAMESPACE = "kube-system", 
    SA_NAME = "cluster-autoscaler"
  })
  tags = {
      "ServiceAccountName"      = "cluster-autoscaler"
      "ServiceAccountNameSpace" = "kube-system"
    }
 
  depends_on = [
    aws_iam_openid_connect_provider.cluster
  ]
}

module "iam_policy_autoscaler" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name = "AmazonEKSClusterAutoscalerPolicy-test"
  path = "/"
  create_policy = true
  description = "Grant autoscaling permissions to EKS node autoscaler"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
  EOF
  tags = {
      PolicyDescription = "EKS Node Autoscaler permissions"
      "Name" = "pol-test-node-autoscaler"
    }

}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role = aws_iam_role.cluster_autoscaler.name
  policy_arn = module.iam_policy_autoscaler.arn
  depends_on = [
    module.iam_policy_autoscaler, aws_iam_role.cluster_autoscaler
  ]
}

module "iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"

  name = "AmazonEKSNodeACMAccess-test"
  path = "/"
  create_policy = true
  description = "Permissions EKS node to get ACM"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "acm:DescribeCertificate",
                "acm:GetCertificate",
                "acm:ListCertificates"
            ],
            "Resource": "*"
        }
    ]
}
  EOF
  tags = {
      PolicyDescription = "Permissions EKS node to get ACM"
      "Name" = "pol-test-eks-acm"
    }
}

module "aws_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"

  create_role = true
  role_name = "AmazonEKSNodeGroupRole-test"
  role_requires_mfa = false

  trusted_role_arns = [
    "arn:aws:iam::000982191218:user/mjs1212",
  ]

  trusted_role_services = [
    "ec2.amazonaws.com"
  ]

  depends_on = [
    module.iam_policy
  ]
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    module.iam_policy.arn
  ]

  tags = {
      "Name" = "rol-test-eks-node"
    }

}

