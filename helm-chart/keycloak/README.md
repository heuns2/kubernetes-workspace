# Key Cloak Helm Install

## Requirements
-  Kubernetes 1.19+
-  Helm 3.2.0+
-  Postgresql 용도의 PVC

## 1. Key Cloak Helm Install

- Key Cloak Helm Repo Add & Update

```
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm repo update
```

- Key Cloak Helm Chart Download

```
# 설치 가능 버전 확인
$ helm search repo bitnami/keycloak --versions
$ helm pull bitnami/keycloak --version=7.1.5 --untar
```

- Affinity 설정

```
$ cat affinity-values.yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: role
          operator: NotIn
          values:
          - "router"
          - "controlplane"
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app.kubernetes.io/component
          operator: In
          values:
          - keycloak
      topologyKey: "kubernetes.io/hostname"
nodeSelector:
  role: "worker"

postgresql:
  primary:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: role
              operator: NotIn
              values:
              - "router"
              - "controlpalne"
    nodeSelector:
      role: "worker"

  readReplicas:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: role
              operator: NotIn
              values:
              - "router"
              - "controlpalne"
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/component
              operator: In
              values:
              - read
          topologyKey: "kubernetes.io/hostname"
    nodeSelector:
      role: "worker"
```

- Extar ENV 파일 구성


```
extraEnv: |
  - name: JGROUPS_DISCOVERY_PROTOCOL
    value: kubernetes.KUBE_PING
  - name: KUBERNETES_NAMESPACE
    valueFrom:
      fieldRef:
        apiVersion: v1
        fieldPath: metadata.namespace
  - name: CACHE_OWNERS_COUNT
    value: "2"
  - name: CACHE_OWNERS_AUTH_SESSIONS_COUNT
    value: "2"


rbac:
  create: true
  rules:
    - apiGroups:
        - ""
      resources:
        - pods
      verbs:
        - get
        - list
```

- keycloak Helm Install

```
$ kubectl create ns keycloak 
$ helm upgrade --install keycloak . --namespace=keycloak \
--set auth.adminPassword=admin \
--set serviceDiscovery.enabled=true \
--set replicaCount=2 \
--set postgresql.architecture=replication \
--set postgresql.readReplicas.replicaCount=3 \
--set replication.numSynchronousReplicas=3 \
--set auth.managementPassword=admin \
--set postgresql.postgresqlPassword=admin \
--set global.storageClass=longhorn \
--set service.type=ClusterIP \
-f values.yaml,affinity-values.yaml
```

- keycloak Ingress 설정

```
$ cat keycloak-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    kubernetes.io/ingress.class: "nginx"
    #kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    nginx.ingress.kubernetes.io/session-cookie-expires: "36000"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "36000"
    ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"

spec:
  rules:
  - host: "keycloak.heun.leedh.xyz"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: keycloak
            port:
              number: 443
  tls:
  - hosts:
    - keycloak.heun.leedh.xyz
    secretName: keycloak-tls

```

## 2. Key Cloak 추가 확인 사항

- Ingress Controller에서 SSL 인증서가 Offloading 될 경우 아래 설정이 추가 될 수 있다.

```
proxyAddressForwarding: true
extraEnvVars:
- name: KEYCLOAK_PROXY_ADDRESS_FORWARDING
  value: "true"
- name: KEYCLOAK_FRONTEND_URL
  value: "https://keycloak.xxx"
```
