
# Promethues Operator (Helm v3 Install)

- Prometheus Operator는 Prometheus 및 관련 Monitoring 구성 요소 의 Kubernetes 기본 배포 및 관리를 제공합니다 . 이 프로젝트의 목적은 Kubernetes 클러스터에 대한 Prometheus 기반 Monitoring 스택의 구성을 단순화하고 자동화가 주 목적으로 하는 프로젝트 입니다.
- Prometheus Operator CRD 기능을 사용하여 Prometheus 컴포넌트의 중단 없이 Config 설정을 변경 할 수 있습니다.
- Service Monitor 기능으로 Promethues 기능이 활성화 되어 있으면 Kubenetes Service와 연동하여 자동으로 Promethues에 Service Discovery 됩니다.
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Prometheus Docs](https://prometheus.io/)

### Requirements
- Version `>=0.39.0` of the Prometheus Operator requires a Kubernetes cluster of version `>=1.16.0`

## 1. Promethues Operator 설치


### 사전 준비 (추가 Metrics 활성화)

- Kube Proxy 설정 변경하여 Prometheus가 Metrics을 수집 할 수 있도록 설정

```
$ kubectl -n kube-system edit cm kube-proxy
metricsBindAddress: 127.0.0.1:10249 # 변경 전
metricsBindAddress: 0.0.0.0:10249 # 변경 후

# Rancher UI에서 Kube Proxy를 Redeploy
```

- Etcd 설정을 변경하여 Prometheus가 Metrics을 수집 할 수 있도록 설정

```
# Master 1번 Node에서 아래 명령어를 통해 etcd-monitoring-certs 생성
$ kubectl create secret generic etcd-monitoring-certs \
--from-file=/etc/ssl/etcd/ssl/etcd.cert \
--from-file=/etc/ssl/etcd/ssl/etcd.pem \
--from-file=/etc/ssl/etcd/ssl/ca.pem \
-n monitoring
```


### 1.1. namespace 생성

-   Promethues 관리용 namespace 생성

```
$ kubectl create namespace monitoring
```

### 1.2. Helm 설정 & Helm Kube Prometheus Stack 설치

- Helm Repo Source Code 다운로드

```
$ helm repo add prometheus https://prometheus-community.github.io/helm-charts

$ helm search repo prometheus/kube-prometheus-stack --versions
$ helm pull prometheus/kube-prometheus-stack --untar --version=34.8.0

```

- Promethues Operator를 관리하기 위해 아래 3가지 values.yaml를 분리

#### 1.2.1. 규모가 커짐에 따라 CPU/Memory Resource 증설을 위한 resource-values.yaml 파일 사용

```
prometheus:
  prometheusSpec:
    resources:
      requests:
        memory: 2048Mi
      limits:
        memory: 4096Mi

alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        memory: 256Mi
      limits:
        memory: 512Mi

grafana:
  resources:
    limits:
      memory: 512Mi
    requests:
      memory: 1024Mi
```

#### 1.2.2. 규모가 커짐에 따라 Disk Resource 증설을 위한 storage-values.yaml 파일 사용

```
prometheus:
  prometheusSpec:
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          accessModes: ["ReadWriteMany"]
          resources:
            requests:
              storage: 50Gi
alertmanager:
  alertmanagerSpec:
      storage:
       volumeClaimTemplate:
         spec:
           storageClassName: longhorn
           accessModes: ["ReadWriteMany"]
           resources:
             requests:
               storage: 10Gi
grafana:
  persistence:
    type: pvc
    enabled: false
    storageClassName: longhorn
    accessModes:
      - ReadWriteMany
    size: 10Gi
```

#### 1.2.3. Infra Node (관리형 Node) 분리를 위한 Node Affinity affinity-values.yaml 파일 사용

```
prometheus:
  prometheusSpec:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: role
              operator: NotIn
              values:
              - "controlplane"
              - "worker"
    nodeSelector:
      role: "infra"

alertmanager:
  alertmanagerSpec:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: role
              operator: NotIn
              values:
              - "controlplane"
              - "worker"
    nodeSelector:
      role: "infra"

grafana:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: role
            operator: NotIn
            values:
            - "controlplane"
            - "worker"

  nodeSelector:
    role: "infra"
```

### 1.3. Helm Promethues Operator Install

- Helm Install

```
$ helm upgrade --install prometheus . --namespace monitoring \
--set grafana.adminPassword=admin \
--set prometheus.prometheusSpec.secrets={etcd-monitoring-certs} \
--set kubeEtcd.endpoints="{ETCD_IP1,ETCD_IP2,ETCD_IP3}" \
--set kubeEtcd.serviceMonitor.scheme=https \
--set kubeEtcd.serviceMonitor.insecureSkipVerify=false \
--set kubeEtcd.serviceMonitor.serverName=localhost \
--set kubeEtcd.serviceMonitor.caFile=/etc/prometheus/secrets/etcd-monitoring-certs/ca.pem \
--set kubeEtcd.serviceMonitor.certFile=/etc/prometheus/secrets/etcd-monitoring-certs/etcd.cert \
--set kubeEtcd.serviceMonitor.keyFile=/etc/prometheus/secrets/etcd-monitoring-certs/etcd.pem \
-f values.yaml,resource-values.yaml,storage-values.yaml,affinity-values.yaml
```

### 1.4.Promethues Operator Ingress 설정

- Grafana, Prometheus, Alert Manager Ingress 설정

```
$ cat ingress.yaml
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
  - host: "grafana.leedh.xyz"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: prometheus-grafana
            port:
              number: 3000
  - host: "prometheus.leedh.xyz"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: prometheus-kube-prometheus-prometheus
            port:
              number: 9090
  - host: "alertmanager.leedh.xyz"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: prometheus-kube-prometheus-alertmanager
            port:
              number: 9093
  tls:
  - hosts:
    - grafana.leedh.xyz
    - prometheus.leedh.xyz
    - alertmanager.leedh.xyz
    secretName: tls-leedh.xyz
```

