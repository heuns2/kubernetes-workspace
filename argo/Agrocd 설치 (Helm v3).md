# Agrocd 설치 (Helm v3)
- 실행 환경
	- AWS EKS 구성
	- Nginx Ingress 구성

## 1. Requirements

### 1.1. Agrocd CLI Install (Linux)

```
$ curl -sLO https://github.com/argoproj/argo-workflows/releases/download/v3.2.3/argo-linux-amd64.gz

# Unzip
$ gunzip argo-linux-amd64.gz

# Make binary executable
$ chmod +x argo-linux-amd64

# Move binary to path
$ sudo mv ./argo-linux-amd64 /usr/local/bin/argo

# Test installation
$ argo version
argo: v3.2.3
  BuildDate: 2021-10-27T02:10:33Z
  GitCommit: e5dc961b7846efe0fe36ab3a0964180eaedd2672
  GitTreeState: clean
  GitTag: v3.2.3
  GoVersion: go1.16.9
  Compiler: gc
  Platform: linux/amd64
```

## 2. Agrocd 설치

### 2.1. namespace 생성

- Agrocd 전용 namespace 생성

```
$ kubectl create ns argo
```

### 2.2. Helm Install & Agrocd 설정

- Agrocd Helm Repo 추가 및 동기화

```
$ helm repo add argo https://argoproj.github.io/argo-helm
$ helm repo update
```

- Agrocd 설치 용 Helm Download

```
$ helm pull argo/argo-cd --untar
```

- Agrocd 설치

```
$ helm install argocd  argo-cd/ \
--namespace=argo \
--set controller.logLevel="info" \
--set server.logLevel="info" \
--set repoServer.logLevel="info" \
--set server.replicas=2 \
--set server.ingress.https=true \
--set repoServer.replicas=2 \
--set controller.enableStatefulSet=true \
--set installCRDs=false
```

### 2.3. Agrocd Ingress 설정

- Https Ingress 용 TLS 인증서 생성

```
$ kubectl create -n argocd secret tls argocd-tls --key eks.leedh.cloud.key --cert eks.leedh.cloud.crt
```

- Argo CD runs both a gRPC server (used by the CLI), as well as a HTTP/HTTPS server 용 Ingress 2개를 생성
- 주의 사항은 Insecure Mode를 활성화 하지 않을 경우 nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"를 명시해줘야 Redirection Loop Error가 발생 하지 않음

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: argocd-server-http-ingress
  namespace: argo
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - http:
      paths:
      - backend:
          serviceName: argocd-server
          servicePort: http
    host: xxx.xxx.xxx.cloud
  tls:
  - hosts:
    - argocd.eks.leedh.cloud
    secretName: argocd-secret # do not change, this is provided by Argo CD

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: argocd-server-grpc-ingress
  namespace: argo
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
spec:
  rules:
  - http:
      paths:
      - backend:
          serviceName: argocd-server
          servicePort: https
    host: grpc.xxx.xxx.leedh.cloud
  tls:
  - hosts:
    - grpc.argocd.eks.leedh.cloud
    secretName: argocd-secret # do not change, this is provided by Argo CD
```

### 2.4. 초기 Password GET

```
$ kubectl -n argo get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## 3. Agrocd UI 확인

- Agrocd UI 확인

![argocd-1][argocd-1]

[argocd-1]:./images/argocd-1.PNG
