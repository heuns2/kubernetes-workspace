# Calico CNI Service Monitor

- Calico CNI의 Metrics을 방출하여 Service Monitor를 통하여 Prometheus에서 모니터링 하는 방안에 대해 설명 합니다.

## 1. Calico CNI Service Monitor 사용

### 1.1. Calico Metrics 활성화

- Rancher UI에서 calico-node DeamonSet 환경 변수 중 아래 FELIX_PROMETHEUSMETRICSENABLED 설정을 True로 변경하여 저장 (Calico Node 재기동)

```
- name: FELIX_PROMETHEUSMETRICSENABLED
  value: "True"
- name: FELIX_PROMETHEUSMETRICSPORT
  value: "9091"
- name: FELIX_PROMETHEUSGOMETRICSENABLED
  value: "True"
- name: FELIX_PROMETHEUSPROCESSMETRICSENABLED
  value: "True"
```

- Felix Metrics Service 노출

```
$ cat felix-metrics-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: felix-metrics-svc
  namespace: kube-system
spec:
  selector:
    k8s-app: calico-node
  ports:
  - port: 9091
    targetPort: 9091
    name: metrics

$ kubectl apply -f felix-metrics-svc.yaml
```

- Calico Kube Controllers Metrics Service 노출

```
$ cat kube-controllers-metrics-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: kube-controllers-metrics-svc
  namespace: kube-system
spec:
  selector:
    k8s-app: calico-kube-controllers
  ports:
  - port: 9094
    targetPort: 9094
    name: metrics

$ kubectl apply -f kube-controllers-metrics-svc.yaml
```

- Label 지정

```
$ kubectl -n kube-system label svc felix-metrics-svc felix-metrics=true
$ kubectl -n kube-system label svc kube-controllers-metrics-svc kube-controllers-metrics=true
```

### 1.2. Service Monitor 설정 

- calico-felix 관련 Service Monitor 설정

```
$ cat calico-felix-service-monitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: calico-felix-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      felix-metrics: "true"
  namespaceSelector:
    matchNames:
    - kube-system
  endpoints:
  - port: metrics
    relabelings:
    - sourceLabels:
      - __meta_kubernetes_endpoint_node_name
      targetLabel: instance

$ kubectl apply -f calico-felix-service-monitor.yaml
```

- calico-kubecontroller 관련 Service Monitor 설정

```
$ cat calico-kube-controllers-service-monitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kube-controllers-metrics
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      kube-controllers-metrics: "true"
  namespaceSelector:
    matchNames:
    - kube-system
  endpoints:
  - port: metrics
    relabelings:
    - sourceLabels:
      - __meta_kubernetes_endpoint_node_name
      targetLabel: instance

$ kubectl apply -f calico-felix-service-monitor.yaml
```

### 1.3. Cailco Grafana 확인

- Grafana Dashboard 확인

![calico-monitor-1][calico-monitor-1]

[calico-monitor-1:./images/calico-monitor-1.PNG
