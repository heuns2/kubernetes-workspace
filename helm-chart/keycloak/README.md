# Key Cloak Helm Install

## Requirements
-  Kubernetes 1.19+
-  Helm 3.2.0+

### 1. HA Postgresql Helm Install & Database 생성

#### 1.1. Helm을 통한 HA Postgresql Install

- HA Postgresql Affinity 설정 파일 생성

```
postgresql:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: role
            operator: NotIn
            values:
            - "controlpalne"
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/component
            operator: In
            values:
            - postgresql
        topologyKey: "kubernetes.io/hostname"

  nodeSelector:
    role: "worker"

pgpool:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: role
            operator: NotIn
            values:
            - "controlpalne"
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/component
            operator: In
            values:
            - pgpool
        topologyKey: "kubernetes.io/hostname"
  nodeSelector:
    role: "worker"
```

- Helm 명령을 통한 HA Postgresql 설치

```
$ helm upgrade --install postgresql-ha . --namespace keycloak \
--set global.storageClass=ceph-filesystem \
--set global.postgresql.password="1q2w3e4r5t" \
--set global.postgresql.repmgrPassword="1q2w3e4r5t" \
--set global.pgpool.adminPassword="1q2w3e4r5t" \
--set pgpool.replicaCount=2 \
--set postgresql.extraEnvVars[0].name=TZ \
--set postgresql.extraEnvVars[0].value=Asia/Seoul \
--set pgpool.extraEnvVars[0].name=TZ \
--set pgpool.extraEnvVars[0].value=Asia/Seoul \
-f values.yaml,affinity-values.yaml
```

- Postgresql 설치 Pod 확인

```
$ kubectl -n keycloak  get pods
NAME                                    READY   STATUS    RESTARTS   AGE
postgresql-ha-pgpool-5f8c845fd5-hxl8m   1/1     Running   0          5m58s
postgresql-ha-pgpool-5f8c845fd5-rplpg   1/1     Running   0          5m58s
postgresql-ha-postgresql-0              1/1     Running   0          5m58s
postgresql-ha-postgresql-1              1/1     Running   0          5m58s
postgresql-ha-postgresql-2              1/1     Running   1          5m58s
```

#### 1.2.  Key Cloak이 사용 할 User / DB 정보 생성

- Postgresql 데이터 생성 용도의 Client Pod 생성 & 접속

```
$ kubectl apply -f 2.yaml/keycloak/postgresql-ha/postgresql-client-pod.yaml
$ kubectl exec -it postgres-client -- bash
```

- Postgresql 데이터 생성

```
$ psql --host postgresql-ha-pgpool.keycloak.svc.cluster.local -U postgres -d postgres -p 5432

$ CREATE DATABASE keycloak ENCODING 'UTF8';
$ CREATE USER keycloak;
$ ALTER USER keycloak WITH ENCRYPTED PASSWORD '1q2w3e4r5t';

$ GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

# Database 확인
$ \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 keycloak  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =Tc/postgres         +
           |          |          |             |             | postgres=CTc/postgres+
           |          |          |             |             | keycloak=CTc/postgres
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 repmgr    | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
```



### 2. Key Cloak Helm Install

#### 2.1. Helm을 이용하여 Key Cloak  Install

- Affinity 설정 파일 생성

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
```

- Key Cloak HA 구성 파일 생성
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

-   Key Cloak Helm Install

```
# Namespace 생성
$ kubectl create ns keycloak 

# Key Cloak 설치
$ helm upgrade --install keycloak . --namespace=keycloak \
--set auth.adminPassword=admin \
--set serviceDiscovery.enabled=true \
--set replicaCount=2 \
--set auth.managementPassword=admin \
--set global.storageClass=ceph-filesystem \
--set service.type=ClusterIP \
--set postgresql.enabled=false \
--set externalDatabase.host='postgresql-ha-pgpool.keycloak.svc.cluster.local' \
--set externalDatabase.user='postgres' \
--set externalDatabase.password='1q2w3e4r5t' \
--set externalDatabase.database=keycloak \
-f values.yaml,affinity-values.yaml,HA-values.yaml
```

#### 2.1.  Key Cloak Ingress 설정

- Key Cloak Ingress를 설정 합니다.

```
$ cat keycloak-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "route"
    nginx.ingress.kubernetes.io/session-cookie-expires: "36000"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "36000"
    ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"

spec:
  rules:
  - host: "keycloak.leedh.xyz"
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
    - keycloak.leedh.xyz
    secretName: tls-cert
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
