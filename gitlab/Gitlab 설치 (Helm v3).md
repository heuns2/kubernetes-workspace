# Gitlab 설치 (Helm v3)
- 실행 환경
	- AWS EKS 구성
	- Nginx Ingress 구성

## 1. Requirements
- kubectl `1.16` or higher, compatible with your cluster
- Helm v3 (3.3.1 or higher).
- Kubernetes cluster, version 1.16 or higher
- 8vCPU and 30GB of RAM is recommended

## 2. Gitlab 설치

### 2.1. namespace 생성

-   Gitlab 관리용 namespace 생성

```
$ kubectl create namespace gitlab 
```

### 2.2. Helm Install & Gitlab 설정

- Gitlab 공식 Helm Repo 추가 & 동기화

```
$ helm repo add gitlab https://charts.gitlab.io/
$ helm repo update
```

- Gitlab Chart Download

```
$ helm pull gitlab/gitlab --untar
```

- Gitlab Install

- Self Sign Certficate를 사용함으로 Certmanager 비 활성화
- Self Sign Certficate를 사용함으로 gitlab-tls Secret 사용 (*.xxx.leedh.cloud)

```
$ helm upgrade --install gitlab gitlab/gitlab \
--namespace=gitlab \
--set global.hosts.domain=xxx.leedh.cloud \
--set global.hosts.externalIP=xxx.xxx.elb.amazonaws.com \
--set certmanager.install=false \
--set nginx-ingress.enabled=false \
--set global.ingress.configureCertmanager=false \
--set global.ingress.tls.secretName=gitlab-tls
```

### 2.3. Gitlab Ingress 설정


## 3. Gitlab UI 확인
