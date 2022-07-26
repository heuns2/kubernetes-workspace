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

  worker_additional_security_group_ids = [module.all_worker_management.security_group_id]


  node_groups_defaults = {
    root_volume_type = "gp2"
  }

  node_groups = {

    normal = {
      name             = "normal"
      desired_capacity = 1
      max_capacity     = 2
      min_capacity     = 1
      disk_size        = 50
      key_name         = module.key_pair.key_pair_name
      instance_types   = ["t2.medium"]
      
      iam_role_arn = module.aws_iam_role.iam_role_arn
      
    }
  }
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
