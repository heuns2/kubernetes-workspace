# Kubernetes  AWS EFS Storage Class 사용

- 본 문서는 Kubernetes에서 AWS Elastics File System를 Storage Class와 연동하여 동적으로 PVC를 요청하는 방안에 대해서 설명 합니다.
- 참고 링크: [eks-efs](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/efs-csi.html)

## 1. AWS EFS 사용 관련 Role 설정

### 1.1. EFS CSI Driver에서 사용 할 수 있는 권한을  설정

- EFS 관련 Policy 정책을 생성 합니다.

```
# EFS 관련 iam-policy 정보
$ cat iam-policy-example.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeAccessPoints",
        "elasticfilesystem:DescribeFileSystems"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:CreateAccessPoint"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/efs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "elasticfilesystem:DeleteAccessPoint",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/efs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}

# Policy 생성
$ aws iam create-policy \ --policy-name `efs-access` \ --policy-document file://iam-policy-example.json
```


![k8s-efs-1][k8s-efs-1]

[k8s-efs-1]:./images/k8s-efs-1.PNG


- EFS 관련 Account Role 정책을 생성 합니다.

```
# Account ID 확인
$ aws sts get-caller-identity
{
    "UserId": "xxxxx",
    "Account": "xxxxxx",
    "Arn": "arn:aws:iam::xxxxx:user/leedh"
}

# cluster.identity.oidc.issuer endpoint 확인
$ aws eks describe-cluster --name {EKS-CLUSTER-NAME} --query "cluster.identity.oidc.issuer" --output text

# EKS Cluster 
$ cat trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::{ACCOUNT-ID}:oidc-provider/oidc.eks.ap-northeast-1.amazonaws.com/id/F4A4C6614C83CEABD463F2XXXXXXX:sub"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.ap-northeast-1.amazonaws.com/id/F4A4C6614C83CEABD463F2XXXXXXX:sub": "system:serviceaccount:kube-system:efs-csi-controller-sa"
        }
      }
    }
  ]
}

# Role 생성
$ aws iam create-role \
  --role-name efs-access \
  --assume-role-policy-document file://"trust-policy.json"

# Role, Policy 정책 연동
$ aws iam attach-role-policy \
  --policy-arn arn:aws:iam::000982191218:policy/efs-access  \
  --role-name efs-access 
```

![k8s-efs-2][k8s-efs-2]

[k8s-efs-2]:./images/k8s-efs-2.PNG


## 2. Kubernetes Storage Class 설정

### 2.1. Kubernetes Storage Class 설정

- EFS CSI를 사용 할 Service Account를 생성 합니다.

```
$ cat serviceaccount.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: efs-csi-controller-sa
  namespace: kube-system
  labels:
    app.kubernetes.io/name: aws-efs-csi-driver
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::xxxxx:role/efs-access

# Service Account 생성
$ kubectl apply -f serviceaccount.yaml
```

- EFS CSI Driver 설치

```
$ kubectl kustomize \ "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/ecr?ref=release-1.3" > driver.yaml

# driver.yaml 중 맨 최 상단 Service Account Block 삭제
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/name: aws-efs-csi-driver
  name: efs-csi-node-sa
  namespace: kube-system

# driver.yaml 중 Docker Image를 아래 특정 Region의 ECR Reposistory로 변경
https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/add-ons-images.html

$ kubectl apply -f driver.yaml
```



- EFS의 Filesystem ID 확인

![k8s-efs-3][k8s-efs-3]

[k8s-efs-3]:./images/k8s-efs-3.PNG

- PVC를 동적 프로비저닝 하기위하여 Storage Class를 생성합니다.

```
$ cat storageclass.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxxxxx
  directoryPerms: "700"
  gidRangeStart: "1000" # optional
  gidRangeEnd: "2000" # optional

$ kubectl apply -f storageclass.yaml
```

- Sample Pod 생성

```
$ cat pod.yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: efs-app
spec:
  containers:
    - name: app
      image: centos
      command: ["/bin/sh"]
      args: ["-c", "while true; do echo $(date -u) >> /data/out; sleep 5; done"]
      volumeMounts:
        - name: persistent-storage
          mountPath: /data
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:

$ kubectl apply -f pod.yaml
```

## 3. Kubernetes - EFS Storage Class 확인

- EFS Storage Class가 올바르게 연동이 되었는지 확인합니다.

```
$ kubectl get storageclass

NAME                  PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
efs-sc                efs.csi.aws.com         Delete          Immediate              false                  28m

$ kubectl describe pod efs-app
Volumes:
  persistent-storage:
    Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
    ClaimName:  efs-claim
    ReadOnly:   false

$ kubectl get pvc

NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
efs-claim   Bound    pvc-73019508-a63e-474c-b965-7611c959a2e8   5Gi        RWX            efs-sc         25m
```

- EFS에 Mount Point가 올바르게 생성이 되었는지 확인 합니다.

![k8s-efs-4][k8s-efs-4]

[k8s-efs-4]:./images/k8s-efs-4.PNG

