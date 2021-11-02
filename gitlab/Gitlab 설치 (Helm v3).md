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
- values.yaml 참고 링크(Global 설정 변수 값): https://docs.gitlab.com/charts/installation/command-line-options.html#outgoing-email-configuration 

```
$ helm upgrade --install gitlab gitlab/ \
--namespace=gitlab \
--set global.hosts.domain=eks.leedh.cloud \
--set gitlab-runner.install=true \
--set global.hosts.externalIP=xxx-xxx.ap-northeast-1.elb.amazonaws.com \
--set certmanager.install=false \
--set nginx-ingress.enabled=false \
--set global.ingress.configureCertmanager=false \
--set global.ingress.tls.secretName=gitlab-tls \
--set gitlab.gitlab-runner.certsSecretName="gitlab-runner-certs" \
--set gitlab-runner.certsSecretName="gitlab-runner-certs" \
--set global.ingress.annotations."kubernetes\.io/ingress\.class"=nginx \
--set gitlab-runner.runners.cache.cacheShared=true \
--set gitlab-runner.runners.cache.secretName=gitlab-minio-secret \
--set gitlab-runner.runners.cache.s3CachePath=runner-cache \
--set gitlab.gitlab-runner.certsSecretName="gitlab-runner-secret"
```

### 2.3. Gitlab Runner 설정 변경

- Gitlab Runner 설정 변경, Cert Manager로 생성 된 인증서가 아닌 Self Sign 인증서를 사용 할 경우 Gitlab Runner에서 아래와 같은 Error Meassge가 발생

```
Couldn't execute POST against https://xxx.com/api/v4/jobs/request: Post https://hostname.tld/api/v4/jobs/request: x509: certificate signed by unknown authority
```

- 위와 같은 에러 발생 시 Runner 아래 설정을 추가
- CA 파일 Secret 생성 (이전 Harbor 설치 시 사용한 CA)

```
$ kubectl create secret generic gitlab-runner-certs \
--from-file=ca.crt
```

- Runner Deployment Yaml File에 gitlab-runner-certs 인증서 Mount와 환경 변수 설정 후 Redeploy

```
volumeMounts:
- mountPath: /etc/gitlab-runner/certs
  name: gitlab-runner-certs
volumes:
- name: gitlab-runner-certs
   secret:
     defaultMode: 438
     secretName: gitlab-runner-certs
env:
- name: CI_SERVER_TLS_CA_FILE
  value: /etc/gitlab-runner/certs/xxx.xxx.leedh.cloud
```

- 위 설정 완료 후 Runner 실행 시 /etc/gitlab-runner/certs/xxx.xxx.leedh.cloud 파일을 읽어 오다 Permission Denie 에러가 발생 할 경우 아래 설정을 0, 0으로 변경하여 Pod Security 변경

```
securityContext:
  fsGroup: 0
  runAsUser: 0
```

- Registration Token 에러가 발생 할 경우 gitlab-gitlab-runner-secret Secret의 runner-registration-token 설정을 변경하여 다시 적용 (프로젝트 생성 후 Token 확인하여 Base64로 인코딩 값 사용)

![gitlab-1][gitlab-1]

[gitlab-1]:./images/gitlab-1.PNG

```
apiVersion: v1
data:
  runner-registration-token: RXlWVFlNZkhEMUJMYjFhOXo3MlgK
  runner-token: ""
kind: Secret
type: Opaque
```

- 초기 Password GET

```
$ kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' | base64 --decode ; echo
```

## 3. Gitlab UI 확인

- UI 확인

![gitlab-2][gitlab-2]

[gitlab-2]:./images/gitlab-2.PNG



