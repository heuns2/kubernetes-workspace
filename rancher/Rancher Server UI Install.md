# Rancher Server UI Install 

- Rancher Server UI는 Rancher Server에 등록 된 Cluster를 관리 하기 위한 DaemonSet을 배포 합니다.

## 1. 설치 준비

### 1.1. Helm v3 Install 
```
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh
```

### 1.2. Rancher UI 설치

- Helm Chart 추가

```
$ helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
$ helm search repo rancher-latest/rancher --versions
$ helm repo update
```

### 1.3. Namespace 생성

- Rancher 관리 용 Namespace를 생성 합니다.

```
# namespace 생성
$ kubectl create namespace cattle-system

# namespace 확인
$  kubectl get namespaces
NAME              STATUS   AGE
cattle-system     Active   8s
```

### 1.4. Rancher 용 SSL 인증서 종류 선택

-   SSL/TLS 인증에 대한 종류를 선택 합니다. Rancher-generated TLS certificate, Let’s Encrypt, Bring your own certificate Type이 존재합니다.
-   본 문서에서는 Default인 Rancher-generated TLS certificate를 사용하여 Cert Manager를 별도로 설치하였습니다.


```
# CustomResourceDefinition 설치
$ kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.7.0/cert-manager.crds.yaml

# Cert Manager 관리 용 
$ kubectl create namespace cert-manager

# Jetstack Helm repository 추가
$ helm repo add jetstack https://charts.jetstack.io
"jetstack" has been added to your repositories

$ helm repo list
NAME            URL
rancher-stable  https://releases.rancher.com/server-charts/stable
jetstack        https://charts.jetstack.io

# Update your local Helm chart repository cache
$ helm repo update
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "rancher-stable" chart repository
Update Complete. ⎈Happy Helming!⎈

# Install the cert-manager Helm chart
$ helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.7.0

# cert-manager Pod 확인
$ kubectl get pods -n cert-manager
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-86f4f985d6-ff8cx              1/1     Running   0          19s
cert-manager-cainjector-56bc5f744c-b2r62   1/1     Running   0          19s
cert-manager-webhook-997b5dd88-nkdp2       1/1     Running   0          19s
```


## 2. Rancher 설치 및 확인

### 2.1. Rancher 설치

-   Rancher Helm Chart 옵션을 확인하고 helm install 명령으로 Rancher를 Kubenetes Cluster에 배포 합니다.
-   [Rancher Helm Chart 옵션](https://rancher.com/docs/rancher/v2.x/en/installation/install-rancher-on-k8s/chart-options/#external-tls-termination)

```
$ helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher-server.prd.leedh.xyz \
  --set replicas=3 \
  --version 2.6.3
```

### 2.2. Rancher 설치 확인

-   설치 된 Rancher의 Pod 형상을 확인 합니다.

```
$ kubectl -n cattle-system rollout status deploy/rancher
Waiting for deployment "rancher" rollout to finish: 0 of 3 updated replicas are available...
Waiting for deployment "rancher" rollout to finish: 1 of 3 updated replicas are available...
Waiting for deployment "rancher" rollout to finish: 2 of 3 updated replicas are available...
deployment "rancher" successfully rolled out
```



