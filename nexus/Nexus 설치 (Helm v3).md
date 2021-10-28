# Nexus 설치 (Helm v3)

## 1. Prerequisites

### 1.1. Software

- Kubernetes (본 가이드는 EKS 환경을 사용)
- Helm CLI (https://helm.sh/docs/intro/install/)


## 2. Nexus 설치

### 2.1. namespace 생성

-   nexus 관리용 namespace 생성

```
$ kubectl create namespace nexus
```

### 2.2. Helm Install & Nexus 설정

-   Helm Nexus Repo 추가 & 동기화

```
$ helm repo add sonatype https://sonatype.github.io/helm3-charts/
$ helm repo update
```

-   Helm Nexus Helm Chart 다운로드

```
$ helm pull sonatype/nexus-repository-manager --untar
```

- Helm Nexus 설치

```
$ helm install nexus-repo nexus-repository-manager/ \
--namespace=nexus \
--set persistence.storageClass=gp2
```

### 2.2. Nexus Ingress 설정

-   인증서 적용을 위해 Secret 생성 cert, key 파일은 harbor 설치 시 사용한 인증서 활용

```
$ kubectl create -n nexus secret tls nexus-tls --key eks.leedh.cloud.key --cert eks.leedh.cloud.crt
```

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nexus-ingress
  namespace: nexus
  annotations:
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    #nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: "xxx.xxx.leedh.cloud"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: nexus-repo-nexus-repository-manager
            port:
              number: 8081
  tls:
  - hosts:
    - xxx.xxx.leedh.cloud
    secretName: nexus-tls
```

## 3. Nexus UI 확인

- Nexus UI 확인

![nexus-1][nexus-1]

[nexus-1]:./images/nexus-1.PNG
