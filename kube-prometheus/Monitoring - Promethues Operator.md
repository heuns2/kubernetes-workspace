# Monitoring - Promethues Operator

- Prometheus Operator는 Prometheus 및 관련 Monitoring 구성 요소 의 Kubernetes 기본 배포 및 관리를 제공합니다 . 이 프로젝트의 목적은 Kubernetes 클러스터에 대한 Prometheus 기반 Monitoring 스택의 구성을 단순화하고 자동화가 주 목적으로 하는 프로젝트 입니다.
- Prometheus Operator CRD 기능을 사용하여 Prometheus 컴포넌트의 중단 없이 Config 설정을 변경 할 수 있습니다.
- Service Monitor 기능으로 Promethues 기능이 활성화 되어 있으면 Kubenetes Service와 연동하여 자동으로 Promethues에 Service Discovery 됩니다.

- 실행 환경
	- AWS EKS 구성
	- Nginx Ingress 구성

### Requirements
- Version `>=0.39.0` of the Prometheus Operator requires a Kubernetes cluster of version `>=1.16.0`

## 1. Promethues Operator 설치

### 1.1. namespace 생성

-   Promethues 관리용 namespace 생성

```
$ kubectl create namespace monitoring
```

### 1.2. Helm 설정

-   Promethues 공식 Helm Repo 추가 & 동기화

```
$ helm repo add prometheus https://prometheus-community.github.io/helm-charts
$ helm repo update

```

-   helm pull stable/prometheus-operator

```
$ helm pull gitlab/gitlab --untar
```

- Promethues Operator를 관리하기 위해 아래 3가지 values.yaml를 분리 함

#### 1.2.1. 규모가 커짐에 따라 CPU/Memory Resource 증설을 위한 resource-values.yaml 파일 사용

```
prometheus:
  prometheusSpec:
    resources:
      requests:
        memory: 2048Mi
      limits:
        memory: 2048Mi

alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        memory: 512Mi
      limits:
        memory: 512Mi

grafana:
  resources:
    limits:
      memory: 512Mi
    requests:
      memory: 512Mi
```

#### 1.2.2. 규모가 커짐에 따라 Disk Resource 증설을 위한 storage-values.yaml 파일 사용

```
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp2
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 51Gi
alertmanager:
  alertmanagerSpec:
      storage:
       volumeClaimTemplate:
         spec:
           storageClassName: gp2
           accessModes: ["ReadWriteOnce"]
           resources:
             requests:
               storage: 11Gi
grafana:
  persistence:
    type: pvc
    enabled: false
    storageClassName: gp2
    accessModes:
      - ReadWriteOnce
    size: 10Gi
    finalizers:
      - kubernetes.io/pvc-protection
```



#### 1.2.3. Management Node (관리형 Node) 분리를 위한 Node Affinity affinity-values.yaml 파일 사용

- 선행 조건으로 특정 Node에 대한 Label을 지정해야 함 본 문서에서는 monitoring: "true" 라는 Label을 생성

```
prometheus:
  prometheusSpec:
    affinity:
     nodeAffinity:
       requiredDuringSchedulingIgnoredDuringExecution:
         nodeSelectorTerms:
         - matchExpressions:
           - key: monitoring
             operator: In
             values:
             - "true"
    nodeSelector:
      monitoring: "true"

alertmanager:
  alertmanagerSpec:
    affinity:
     nodeAffinity:
       requiredDuringSchedulingIgnoredDuringExecution:
         nodeSelectorTerms:
         - matchExpressions:
           - key: monitoring
             operator: In
             values:
             - "true"
    nodeSelector:
      monitoring: "true"

grafana:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: monitoring
           operator: In
           values:
           - "true"
  nodeSelector:
    monitoring: "true"
```

### 1.3. Helm Promethues Operator Install

- EKS는 Control Plane 영역은 사용자가 관리하지 않음으로 Service Monitor를 Disable로 변경하여 Helm install

```
$ helm upgrade --install prometheus . --namespace monitoring \
--set grafana.adminPassword=admin \
--set kubeApiServer.enabled=false \
--set kubeControllerManager.enabled=false \
--set kubeEtcd.enabled=false \
--set kubeScheduler.enabled=false \
--set kubelet.serviceMonitor.resource=false \
-f values.yaml,resource-values.yaml,storage-values.yaml,affinity-values.yaml
```

### 1.4.Promethues Operator Ingress 설정

- Https 통신 용 TLS 인증서 생성

```
$ kubectl create -n monitoring secret tls monitoring-tls --key eks.leedh.cloud.key --cert eks.leedh.cloud.crt
```

- Grafana, Prometheus, Alert Manager Ingress 설정

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  rules:
  - host: "xxx.eks.leedh.cloud"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 3000
  tls:
  - hosts:
    - xxx.eks.leedh.cloud
    secretName: monitoring-tls
```

### 2.Promethues Operator UI 확인

- Grafana

![promethues-operator-1][promethues-operator-1]

[promethues-operator-1]:./images/promethues-operator-1.PNG

- Prometheus

![promethues-operator-2][promethues-operator-2]

[promethues-operator-2]:./images/promethues-operator-2.PNG

- Alert Manager

![promethues-operator-3][promethues-operator-3]

[promethues-operator-3]:./images/promethues-operator-3.PNG

