# x509 SSL Certificate 만료 기한 확인

- Prometheus Operator를 통하여 Service Monitor를 추가하여 x509 SSL Certificate 인증서 만료 기한을 확인하는 Dashboard 연동 방안에 대하여 설명 합니다.
- 아래 파일들에 대하여 유효 기간을 체크 합니다.
    - Kubernetes 클러스터의 TLS 비밀
    - 경로 또는 검색 디렉토리별 PEM 인코딩 파일
    - 인증서 또는 파일 참조가 포함된 Kube configs
- [참고자료 Helm Chart](https://github.com/enix/helm-charts/tree/master/charts/x509-certificate-exporter#-tldr)

## Prerequisites
- Helm v3
- Prometheus Operator
- Containerd기반의 Kuberspray를 기반으로 합니다.


## 1. x509-certificate-exporter Helm Install

### 1.1. x509-certificate-exporter Install

- 설치 디렉토리로 이동합니다.

```
$ cd 2.yaml/kube-prometheus-stack/cert-monitor/x509-certificate-exporter
```

- values.yaml 수정, 아래 라인을 수정하여 Control Plane과 모든 Node에 설치 될 수 있도록 구성하며 각 Node 별로 만료 기한을 감시 할 인증서를 명시합니다.

```
  daemonSets:
    cp:
      nodeSelector:
        node-role.kubernetes.io/master: ""
      tolerations:
      - key: controlplane
        operator: Exists
      watchFiles:
      - /var/lib/kubelet/pki/kubelet-client-current.pem
      - /etc/kubernetes/pki/apiserver.crt
      - /etc/kubernetes/pki/apiserver-etcd-client.crt
      - /etc/kubernetes/pki/apiserver-kubelet-client.crt
      - /etc/kubernetes/pki/ca.crt
      - /etc/kubernetes/pki/front-proxy-ca.crt
      - /etc/kubernetes/pki/front-proxy-client.crt
      - /etc/ssl/etcd/ssl/ca.pem
      - /etc/ssl/etcd/ssl/member-node1.pem
      - /etc/ssl/etcd/ssl/member-node2.pem
      - /etc/ssl/etcd/ssl/member-node3.pem
      - /etc/ssl/etcd/ssl/admin-node1.pem
      - /etc/ssl/etcd/ssl/admin-node2.pem
      - /etc/ssl/etcd/ssl/admin-node3.pem
      watchKubeconfFiles:
      - /etc/kubernetes/admin.conf
      - /etc/kubernetes/controller-manager.conf
      - /etc/kubernetes/scheduler.conf

    nodes:
      tolerations:
      - effect: NoSchedule
        operator: Exists
      watchFiles:
      - /var/lib/kubelet/pki/kubelet-client-current.pem
      - /etc/kubernetes/pki/ca.crt
```

- Helm Install

```
$ helm upgrade --install x509-certificate-exporter . --namespace=monitoring
```

- x509 Exporter Deamo Set Pod 확인

```
kubectl -n monitoring  get pods | grep x509
x509-certificate-exporter-cp-dd4dl                       1/1     Running   0          32m
x509-certificate-exporter-cp-qgr79                       1/1     Running   0          32m
x509-certificate-exporter-cp-xbcbh                       1/1     Running   0          32m
x509-certificate-exporter-d5dcb9994-fmdn8                1/1     Running   0          36m
x509-certificate-exporter-nodes-5gjl6                    1/1     Running   0          27m
x509-certificate-exporter-nodes-9fk7p                    1/1     Running   0          27m
x509-certificate-exporter-nodes-kzrfq                    1/1     Running   0          27m
x509-certificate-exporter-nodes-l64zm                    1/1     Running   0          26m
x509-certificate-exporter-nodes-mp9s5                    1/1     Running   0          26m
x509-certificate-exporter-nodes-p46hs                    1/1     Running   0          27m
x509-certificate-exporter-nodes-ptzlb                    1/1     Running   0          27m
x509-certificate-exporter-nodes-qhl8w                    1/1     Running   0          27m
x509-certificate-exporter-nodes-qr2tz                    1/1     Running   0          26m
x509-certificate-exporter-nodes-s2mcp                    1/1     Running   0          27m
x509-certificate-exporter-nodes-t6bdz                    1/1     Running   0          27m
x509-certificate-exporter-nodes-vbfg8                    1/1     Running   0          27m
```

## 2. Promethues 연동

### 2.1. Service Monitor 생성

- Service Monitor를 생성하여 Prometheus가 Metrics을 Discovery 할 수 있도록 합니다.

```
$ cat certificate-x509-expired-service-monitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: x509-certificate-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  endpoints:
  - interval: 60s
    port: metrics
    scrapeTimeout: 10s
  selector:
    matchLabels:
      app.kubernetes.io/instance: x509-certificate-exporter
      app.kubernetes.io/name: x509-certificate-exporter

$ kubectl apply -f certificate-x509-expired-service-monitor.yaml
```

### 2.2. 확인
- Prometheus UI에서 [Status] 드롭 다운 메뉴 -> [Service Discovery] 화면으로 이동하여 x509-certificate-metrics이 정상적으로 Targeting 되었는지 확인 합니다.
- Grafana에 Dashboard Json 파일을 업로드하여 저장합니다.
