# Kube Event Exporter Install

- 본 문서는 Kubernetes Event의 영역을 Exporter를 통하여 EFK에 쌓고 확인 하는 방안 입니다.
- 기본적으로 Kube Event History는 Default 1h 단위까지 확인이 가능하며 그 이후로는 사라지는 휘발성 데이터 입니다.
- 사전 EFK를 통하여 Service가 존재하여야 합니다.
- Exporter도 Monitoring Role에 사용 됨으로 Prometheus가 설치 되어 있는 곳에 배포 됩니다.

## 1. Kube Event Exporter 소스 코드 변경

### 1.1. Kube Event Exporter 설치

- 읽기 권한에 대한 Cluster Role 생성

```
$ cat 00-view-clusterrole.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: event-exporter-view
rules:
- apiGroups:
  - "*"
  resources:
  - '*'
  verbs:
  - get
  - list
  - watch

$ kubectl apply -f 00-view-clusterrole.yaml
```

- Cluster Role Bind 생성, Event Exporter가 사용 할 ServiceAccount와 Cluster Role을 연동

```
$ cat 01-roles.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: monitoring
  name: event-exporter
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: event-exporter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: event-exporter-view
subjects:
  - kind: ServiceAccount
    namespace: monitoring
    name: event-exporter
$ kubectl apply -f 01-roles.yaml
```

- EKF로 Event를 발생 시키는 Config 파일 설정

```
$ cat 02-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: event-exporter-cfg
  namespace: monitoring
data:
  config.yaml: |
    logLevel: error
    logFormat: json
    route:
      routes:
        - drop:
          - type: "Normal"
        - match:
          - receiver: dump
        - drop:
          - type: "Normal"
    receivers:
      - name: "dump"
        elasticsearch:
          hosts:
            - http://elasticsearch-master.efk.svc.cluster.local:9200
          index: kube-events
          indexFormat: "kube-events-{2006-01-02}"
          useEventID: true
          deDot: true

$ kubectl apply -f 02-config.yaml
```

- Kubernetes Event Exporter 배포

```
$ cat 03-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-exporter
  namespace: monitoring
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: event-exporter
        version: v1
    spec:
      serviceAccountName: event-exporter
      containers:
        - name: event-exporter
          image: ghcr.io/opsgenie/kubernetes-event-exporter:v0.11
          imagePullPolicy: IfNotPresent
          args:
            - -conf=/data/config.yaml
          volumeMounts:
            - mountPath: /data
              name: cfg
      volumes:
        - name: cfg
          configMap:
            name: event-exporter-cfg
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: role
                operator: NotIn
                values:
                - controlpalne
      nodeSelector:
        role: worker
  selector:
    matchLabels:
      app: event-exporter
      version: v1

$ kubectl apply -f 03-deployment.yaml
```

