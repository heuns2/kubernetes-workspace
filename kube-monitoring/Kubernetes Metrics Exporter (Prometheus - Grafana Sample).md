# 1. Kubernetes Metrics Exporter (Prometheus - Grafana Sample)

- 테스트 환경: AWS, kops
- System Component Metrics으로 내부에서 발생하는 상황을 더 잘 파악할 수 있다. Metrics은 Dashboard와 Alert를 만드는 데 특히 유용하다.
- Kubernetes Component의 Metrics은 Prometheus으로 출력된다.
- 가져 올 수 있는 Component는 아래와 같습니다.
	- kube-controller-manager
	- kube-proxy
	- kube-apiserver
	- kube-scheduler
	- kubelet

- 주의 사항으로는 내부적으로 RBAC를 사용 할 경우 /metrics endpoint에 대해 별도의 serviceaccounts를 생성 해야 할 수 있다.

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
  - nonResourceURLs:
      - "/metrics"
    verbs:
      - get
```


## 1.1. Prometheus 연동

- Prometheus 관련 Pod들 배치를 위한 namespace 생성

```
$ kubectl create namespace prometheus 
```

- Prometheus 관련 Endpoint에 접근 할 수 있는 Role 생성 및 bind

```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: prometheus
  namespace: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups:
  - extensions
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: default
  namespace: prometheus
$ kubectl apply -f promethues-role.yml
```

- Prometheus 관련 모든 Pod가 사용 할 Configmap 생성 (Prometheus 실행 설정 파일)

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-conf-v2.0
  labels:
    name: prometheus-server-conf-v2.0
  namespace: prometheus
data:
  prometheus.rules: |-
    groups:
    - name: container memory alert
      rules:
      - alert: container memory usage rate is very high( > 55%)
        expr: sum(container_memory_working_set_bytes{pod!="", name=""})/ sum (kube_node_status_allocatable_memory_bytes) * 100 > 55
        for: 1m
        labels:
          severity: fatal
        annotations:
          summary: High Memory Usage on
          identifier: ""
          description: " Memory Usage: "
    - name: container CPU alert
      rules:
      - alert: container CPU usage rate is very high( > 10%)
        expr: sum (rate (container_cpu_usage_seconds_total{pod!=""}[1m])) / sum (machine_cpu_cores) * 100 > 10
        for: 1m
        labels:
          severity: fatal
        annotations:
          summary: High Cpu Usage
  prometheus.yml: |-
    global:
      scrape_interval: 5s
      evaluation_interval: 5s
    rule_files:
      - /etc/prometheus/prometheus.rules
    alerting:
      alertmanagers:
      - scheme: http
        static_configs:
        - targets:
          - "alertmanager.monitoring.svc:9093"
    scrape_configs:
      - job_name: 'kubernetes-apiservers12345'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          server_name: kubernetes
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https
      - job_name: 'kubernetes-nodes'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
          target_label: __address__
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_pod_name]
          action: replace
          target_label: kubernetes_pod_name
      - job_name: 'kube-state-metrics'
        static_configs:
          - targets: ['kube-state-metrics.kube-system.svc.cluster.local:8080']
      - job_name: 'kubernetes-cadvisor'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
      - job_name: 'kubernetes-service-endpoints'
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
          action: replace
          target_label: __scheme__
          regex: (https?)
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          action: replace
          target_label: kubernetes_name
```

- Prometheus Server Pod 실행

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-deployment
  namespace: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus-server
  template:
    metadata:
      labels:
        app: prometheus-server
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:latest
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
            - "--storage.tsdb.path=/prometheus/"
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: prometheus-config-volume
              mountPath: /etc/prometheus/
            - name: prometheus-storage-volume
              mountPath: /prometheus/
      volumes:
        - name: prometheus-config-volume
          configMap:
            defaultMode: 420
            name: prometheus-server-conf
        - name: prometheus-storage-volume
          emptyDir: {}
$ kubectl apply -f prometheus-deployment.yaml
```

- Prometheus Node Exporter Pod 배포 (Exporter는 전체 노드에 배포가 되어야 하기 때문에 DaemonSet 형태로 배포되며, Node 내부에서 Metrics을 Prometheus로 Export해주는 역할을 한다.)

```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: prometheus
  labels:
    k8s-app: node-exporter
spec:
  selector:
    matchLabels:
      k8s-app: node-exporter
  template:
    metadata:
      labels:
        k8s-app: node-exporter
    spec:
      containers:
      - image: prom/node-exporter
        name: node-exporter
        ports:
        - containerPort: 9100
          protocol: TCP
          name: http
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: node-exporter
  name: node-exporter
  namespace: kube-system
spec:
  ports:
  - name: http
    port: 9100
    nodePort: 31672
    protocol: TCP
  type: NodePort
  selector:
    k8s-app: node-exporter
```

- Prometheus Server Pod를 외부로 노출 시켜주는 Service 생성

```
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: prometheus
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/port:   '9090'
spec:
  selector:
    app: prometheus-server
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 9090
```

## 1.2. Prometheus 결과 확인

- Gafana 화면에서 Query를 실행 할 Promethues의 Metrics Endpoint로 접근하여 Metrics 정보를 확인
![prom-1][prom-1]

[prom-1]:./images/prom-image-1.PNG



## 2.1. Grafana 연동

- Grafana Server의 Container 생성

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      name: grafana
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - name: grafana
          containerPort: 3000
        env:
        - name: GF_SERVER_HTTP_PORT
          value: "3000"
        - name: GF_AUTH_BASIC_ENABLED
          value: "false"
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ORG_ROLE
          value: Admin
        - name: GF_SERVER_ROOT_URL
          value: /
$ kubectl apply -f grafana-deployment.yaml
```

- Grafana Server에 외부 접근 가능한 Service 생성

```
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: prometheus
  annotations:
      prometheus.io/scrape: 'true'
      prometheus.io/port:   '3000'
spec:
  selector:
    app: grafana
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 3000
$ kubectl apply -f grafana-service.yaml
```


## 2.2. Grafana 결과 확인
- Service로 생성 된 Grafana의 UI가 정상적으로 보이는지 확인

![prom-2][prom-2]

[prom-2]:./images/prom-image-2.PNG


## 3.1. Grafana - Prometheus 사용

### 3.1.1. Datastore 생성
- Datastore Prometheus Type의 URL에 Promethues URL를 설정하고 [Save] 버튼을 클릭

![prom-3][prom-3]

[prom-3]:./images/prom-image-3.PNG

### 3.1.2. Sample Dashboard 생성
- Promql을 기반으로 Sample Dashboard를 생성합니다.


#### 3.1.2.1. Sample Dashboard 변수 설정
- Namespace, Pod, Node 등의 확인 Metrics에 대한 Label 변수 값을 설정 한다.

![prom-4][prom-4]

[prom-4]:./images/prom-image-4.PNG


#### 3.1.2.2. Sample Panel 생성
- 위에서 선언한 변수 값을 동적으로 받아 Promsql Query를 실행 한다.

```
sum(kube_pod_info{namespace=~"$namespace", pod=~"$pod"})
sum(kube_pod_status_phase{pod=~"$pod", namespace=~"$namespace", phase="Running"})
```

![prom-5][prom-5]

[prom-5]:./images/prom-image-5.PNG


#### 3.1.2.3. Sample Dashboard 확인

![prom-6][prom-6]

[prom-6]:./images/prom-image-6.PNG
