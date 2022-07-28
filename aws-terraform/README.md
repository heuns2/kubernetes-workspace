# 주요 파일 구조

- infra-architecture.png: 해당 주소의 Terraform을 통해 Provisioning 되는 AWS Infra 예측 구성도
- infra-create.tf: Kubernetes(EKS) 구성을 위하여 필요한 AWS Resource Provisioning Terraform 파일 (VPC, Subnet, Routing Table, Nat G/W, ELP, EFS, Key Pair, ECR 등)
- eks-create.tf: EKS Node Provisioning Terraform 파일
- bastion-vm-create.tf: Bastion VM ec2 생성 Provisioning Terraform 파일
- outputs.tf: Terraform 실행 후 필요한 정보(key pair, kubeconfig 등)를 가져 오기 위하여 작성 한 파일
- variables.tf: Terraform 실행 변수 파일
- versions.tf: Terraform 실행 버전 파일


### 예상 구성도

![infra-architecture][infra-architecture]

[infra-architecture]:./infra-architecture.png
