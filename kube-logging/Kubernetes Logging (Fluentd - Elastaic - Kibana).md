
# 1. Kubernetes Logging (Fluentd - Elastaic - Kibana)

- 테스트 환경: AWS, kops
- Pod 또는 System 대한 로그를 확인 할 때 해당 Pod 또는 Node가 delete 또는 restart 되거나 crash 되는 상태가 발생하게 되면 관련된 로그를 더 이상 확인 할 수 없는 문제점이 있다.
- 대규모로 분산 된 Pod의 로그를 Filtering하여 효과적으로 검색 및 추출 할 수 있다.

## 1.1. Fluentd - Elastaic - Kibana 구성

- DaemonSet의 사용 
	- Glusterd, Ceph와 같은 스토리지를 모든 Node에서 실행
	- Fluentd 또는 Logstash와 같은 Log 수집기를 모든 Node에서 실행
	- Promethues, Dynatrace OneAgent와 같은 Metrics 수집기 Agent를 모든 Node에서 실행

- StatefulSet의 사용
	- 일반 Deployments와 다르게 계속하여 같은 정보의 고유성을 사용 할 수 있게 해주는 API 개체
	- network, persistent storage 등 고유한 속성을 사용 하고 싶을 때 사용

- 참고 URL
	- https://gitlab.com/ndevox/kubernetes-elastic-logging/blob/master/elasticsearch-ss.yaml 
	- https://gitlab.com/ndevox/kubernetes-elastic-logging/blob/master/kibana-deployment.yaml


### 1.1. Namespace 생성
- EFK 관리 Pod 용 namespace 생성

```
$ kubectl create namespace elk
```

### 1.2. EFK에서 사용할 API에 대해 RABC 구성

```
# RBAC authn and authz
apiVersion: v1
kind: ServiceAccount
metadata:
  name: elasticsearch-logging
  namespace: elk
  labels:
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: elasticsearch-logging
  labels:
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
rules:
- apiGroups:
  - ""
  resources:
  - "services"
  - "namespaces"
  - "endpoints"
  verbs:
  - "get"
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: elk
  name: elasticsearch-logging
  labels:
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
subjects:
- kind: ServiceAccount
  name: elasticsearch-logging
  namespace: elk
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: elasticsearch-logging
  apiGroup: ""

$ kubectl apply -f elk-rbac.yaml
```

### 1.3. Elasticsearch Container 생성

```
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch-logging
  namespace: elk
  labels:
    k8s-app: elasticsearch-logging
    version: v6.2.4
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  serviceName: elasticsearch-logging
  replicas: 2
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      k8s-app: elasticsearch-logging
      version: v6.2.4
  template:
    metadata:
      labels:
        k8s-app: elasticsearch-logging
        version: v6.2.4
        kubernetes.io/cluster-service: "true"
    spec:
      serviceAccountName: elasticsearch-logging
      containers:
      - image: k8s.gcr.io/elasticsearch:v6.2.4
        name: elasticsearch-logging
        resources:
          # need more cpu upon initialization, therefore burstable class
          limits:
            cpu: 1000m
          requests:
            cpu: 100m
        ports:
        - containerPort: 9200
          name: db
          protocol: TCP
        - containerPort: 9300
          name: transport
          protocol: TCP
        volumeMounts:
        - name: elasticsearch-logging
          mountPath: /data
        env:
        - name: "NAMESPACE"
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
      volumes:
      - name: elasticsearch-logging
        emptyDir: {}
      # Elasticsearch requires vm.max_map_count to be at least 262144.
      # If your OS already sets up this number to a higher value, feel free
      # to remove this init container.
      initContainers:
      - image: alpine:3.6
        command: ["/sbin/sysctl", "-w", "vm.max_map_count=262144"]
        name: elasticsearch-logging-init
        securityContext:
          privileged: true

---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-logging
  namespace: elk
  labels:
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "Elasticsearch"
spec:
  type: LoadBalancer
  ports:
  - port: 9200
    protocol: TCP
    targetPort: db
  selector:
    k8s-app: elasticsearch-logging
```

### 1.4. Fluentd Container 생성
- 주의 사항으로는 Fluentd를 통하여 수집되는 Log를 보내는 Elasticsearch의 Endpoint가 명시 되어야 한다.
- 모든 Node의 Log를 수집하기 위해 DaemonSet으로 구성

```
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: fluentd
  name: fluentd
  namespace: elk

---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: fluentd
rules:
  - apiGroups:
      - ""
    resources:
      - "namespaces"
      - "pods"
    verbs:
      - "list"
      - "get"
      - "watch"

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: fluentd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fluentd
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: elk

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: elk
  labels:
    k8s-app: fluentd-logging
    version: v1
    kubernetes.io/cluster-service: "true"
spec:
  selector:
    matchLabels:
      k8s-app: fluentd-logging
  template:
    metadata:
      labels:
        k8s-app: fluentd-logging
        version: v1
        kubernetes.io/cluster-service: "true"
    spec:
      serviceAccount: fluentd
      serviceAccountName: fluentd
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1.4.2-debian-elasticsearch-1.1
        env:
          - name:  FLUENT_ELASTICSEARCH_HOST
            value: "abfc010d05319474b91aff412ece2f9d-1014437851.ap-northeast-1.elb.amazonaws.com"
          - name:  FLUENT_ELASTICSEARCH_PORT
            value: "9200"
          - name: FLUENT_ELASTICSEARCH_SCHEME
            value: "http"
          - name: FLUENTD_SYSTEMD_CONF
            value: "disable"
          - name: FLUENT_UID
            value: "0"
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```


### 1.5. Kibana Container 생성
- kibana UI Container를 생성 한다.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana-logging
  namespace: elk
  labels:
    k8s-app: kibana-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: kibana-logging
  template:
    metadata:
      labels:
        k8s-app: kibana-logging
      annotations:
        seccomp.security.alpha.kubernetes.io/pod: 'docker/default'
    spec:
      containers:
      - name: kibana-logging
        image: docker.elastic.co/kibana/kibana-oss:6.2.4
        resources:
          # need more cpu upon initialization, therefore burstable class
          limits:
            cpu: 1000m
          requests:
            cpu: 100m
        env:
          - name: ELASTICSEARCH_URL
            value: http://abfc010d05319474b91aff412ece2f9d-1014437851.ap-northeast-1.elb.amazonaws.com:9200
        ports:
        - containerPort: 5601
          name: ui
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: kibana-logging
  namespace: elk
  labels:
    k8s-app: kibana-logging
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "Kibana"
spec:
  type: LoadBalancer
  ports:
  - port: 5601
    protocol: TCP
    targetPort: ui
  selector:
    k8s-app: kibana
```

## 2. Kibana Dashboard 확인

### 2.1. Kibana Index 설정
- Kibana의 Dashboard UI에서 Elasticsearch의 Index를 설정 한다.

![kibana-1][kibana-1]

[kibana-1]:./images/kibana-image-1.PNG


### 2.2. Kibana Log 확인
- Kibana 화면에서 namespace: leedh의 pod tomcat log 확인

![kibana-2][kibana-2]

[kibana-2]:./images/kibana-image-2.PNG

![kibana-5][kibana-5]

[kibana-5]:./images/kibana-image-5.PNG


### 2.3. Kibana Sample Dashboard 확인
- Kibana 화면에서 namespace: leedh의 pod tomcat log 확인

![kibana-3][kibana-3]

[kibana-3]:./images/kibana-image-3.PNG


![kibana-4][kibana-4]

[kibana-4]:./images/kibana-image-4.PNG


