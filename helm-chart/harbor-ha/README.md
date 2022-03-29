
# HA Harbor Install Helm

## Prerequisites

- High available ingress controller
- 외부 HA 구성의 PostgreSQL database
- 외부 HA 구성의 Redis
- RWX(ReadWriteMany)형태의 데이터 공유가 가능한 PVC (NFS, Object Storage)


## Harbor Configuration

## 1. External Redis Install

### 1.1. Cluster 구성의 Redis 생성

- Harbor 배포 용 Namespace 구성

```
$ kubectl create ns harbor
```

- Helm을 통한 Redis 구성

```
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm repo update

# 설치 가능한 Redis 확인
$ helm search repo bitnami/redis --versions

# Source Code Download
$ helm pull bitnami/redis-cluster --version=7.4.0 --untar

# Storage Node를 사용하기 위해 Affinity 사용
$ cat affinity-values.yaml
redis:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
    
updateJob:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"

# value.yaml에 아래 라인 변경 (2개)
  accessModes:
    - ReadWriteMany


# Reids Cluster Install
$ helm upgrade --install redis . --namespace harbor \
--set global.storageClass=ceph-filesystem \
--set sentinel.enabled=true \
--set global.redis.password="1q2w3e4r5t" \
--set auth.sentinel=false \
-f values.yaml,affinity-values.yaml

# Pod 형상 확인
$ kubectl -n harbor get pods
NAME              READY   STATUS    RESTARTS   AGE
redis-node-0                            2/2     Running   0          14m
redis-node-1                            2/2     Running   0          13m
redis-node-2                            2/2     Running   0          12m

# Reids Password 확인
$ kubectl get secret --namespace harbor redis -o jsonpath="{.data.redis-password}" | base64 --decode
```

## 2. External Postgres Install

### 2.1. HA 구성의 Postgres 생성

- Helm을 통한 Postgres구성

```
# 설치 가능 postgresql-ha 버전 확인
$ helm search repo bitnami/postgresql-ha --versions

$ helm pull bitnami/postgresql-ha  --version=8.6.4 --untar

# value.yaml에 아래 라인 변경
  accessModes:
    - ReadWriteMany

# Helm Install Postgres
helm install postgresql-ha . --namespace harbor \
--set global.storageClass=ceph-filesystem \
-f values.yaml,affinity-values.yaml

# Pod 형상 확인
# $ kubectl -n harbor get pods
NAME                                    READY   STATUS    RESTARTS   AGE
postgresql-ha-pgpool-86d7f66dbb-7t98j   1/1     Running   1          2m36s
postgresql-ha-postgresql-0              1/1     Running   0          2m36s
postgresql-ha-postgresql-1              1/1     Running   1          2m36s
postgresql-ha-postgresql-2              1/1     Running   1          2m35s
redis-cluster-0                         1/1     Running   0          34m
redis-cluster-1                         1/1     Running   0          34m
redis-cluster-2                         1/1     Running   0          34m
redis-cluster-3                         1/1     Running   0          34m
redis-cluster-4                         1/1     Running   0          34m
redis-cluster-5                         1/1     Running   0          34m

# Postgres 접근 패스워드 확인
$ kubectl get secret --namespace harbor postgresql-ha-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode

# pgpool DNS 확인
$ postgresql-ha-pgpool.harbor.svc.cluster.local
```

## 3. Harbor HA Install

- Helm을 통한 Harbor구성

```
# 설치 가능 postgresql-ha 버전 확인
$ helm repo add harbor https://helm.goharbor.io
$ helm search repo harbor/harbor --versions

# Harbor Helm Chart 다운로드
$ helm pull harbor/harbor --version=1.8.2 --untar

# affinity 설정
nginx:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

portal:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

core:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

jobservice:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

registry:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

chartmuseum:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

notary:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

exporter:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists
nginx:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

portal:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

core:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

jobservice:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

registry:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

chartmuseum:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

notary:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists

exporter:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlpalne"
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists


# Harobr DB 생성
$ cat postgresql-client-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: postgres-client
  name: postgres-client
spec:
  nodeSelector:
    node-type: "storage"
  tolerations:
  - key: storage-node
    operator: Exists
  containers:
  - env:
    - name: POSTGRES_PASSWORD
      value: Gt60l9p8rQ
    image: postgres:11
    name: postgres-client
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}

$ kubectl apply -f postgresql-client-pod.yaml

$ kubectl exec -it postgres-client -- sh

$ psql --host postgresql-ha-pgpool.harbor.svc.cluster.local -U postgres -d postgres -p 5432

-- Create required databases
CREATE DATABASE notary_server ENCODING 'UTF8';
CREATE DATABASE notary_signer ENCODING 'UTF8';
CREATE DATABASE registry ENCODING 'UTF8';


-- Create harbor user
-- The helm chart limits us to a single user for all databases
CREATE USER harbor;
ALTER USER harbor WITH ENCRYPTED PASSWORD 'change-this-password';

-- Grant the user access to the DBs
GRANT ALL PRIVILEGES ON DATABASE notaryserver TO harbor;
GRANT ALL PRIVILEGES ON DATABASE notarysigner TO harbor;
GRANT ALL PRIVILEGES ON DATABASE registry TO harbor;
GRANT ALL PRIVILEGES ON DATABASE clair to clair;

# Helm Install
$ helm upgrade --install harbor . --namespace harbor \
--set expose.ingress.hosts.core=core.harbor.heun.leedh.xyz \
--set expose.ingress.hosts.notary=notary.harbor.heun.leedh.xyz \
--set externalURL=harbor.heun.leedh.xyz \
--set database.type=external \
--set database.external.host="postgresql-ha-pgpool.harbor.svc.cluster.local" \
--set database.external.password="Gt60l9p8rQ" \
--set database.external.username=postgres \
--set redis.type=external \
--set redis.external.addr="redis.harbor.svc.cluster.local:26379" \
--set redis.external.password="1q2w3e4r5t" \
--set redis.external.sentinelMasterSet=mymaster \
--set persistence.persistentVolumeClaim.registry.storageClass=ceph-filesystem \
--set persistence.persistentVolumeClaim.chartmuseum.storageClass=ceph-filesystem \
--set persistence.persistentVolumeClaim.jobservice.storageClass=ceph-filesystem \
--set persistence.persistentVolumeClaim.registry.accessMode=ReadWriteMany \
--set persistence.persistentVolumeClaim.chartmuseum.accessMode=ReadWriteMany \
--set persistence.persistentVolumeClaim.jobservice.accessMode=ReadWriteMany \
--set portal.replicas=2 \
--set core.replicas=2 \
--set jobservice.replicas=2 \
--set registry.replicas=2 \
--set chartmuseum.replicas=2 \
--set notary.server.replicas=2 \
--set notary.signer.replicas=2 \
-f values.yaml,affinity-values.yaml
```

## 4. Harbor 확인


```
$ kubectl -n harbor get pods
NAME                                    READY   STATUS    RESTARTS   AGE
harbor-chartmuseum-694fb4cdc9-d2m7k     1/1     Running   0          4m15s
harbor-chartmuseum-694fb4cdc9-jhsf4     1/1     Running   0          4m15s
harbor-core-6c88f5c677-7zm7t            1/1     Running   0          4m15s
harbor-core-6c88f5c677-dh26v            1/1     Running   0          4m15s
harbor-jobservice-78f4fc4bfc-bn2wk      1/1     Running   0          4m15s
harbor-jobservice-78f4fc4bfc-fmgnk      1/1     Running   0          4m15s
harbor-notary-server-67cd964788-9bnz4   1/1     Running   0          4m15s
harbor-notary-server-67cd964788-jlnhg   1/1     Running   0          4m15s
harbor-notary-signer-65b5c66878-qt4xk   1/1     Running   0          4m15s
harbor-notary-signer-65b5c66878-zk2hs   1/1     Running   0          4m15s
harbor-portal-79d46c955f-8vq9d          1/1     Running   0          4m15s
harbor-portal-79d46c955f-kgzhg          1/1     Running   0          4m15s
harbor-registry-d4df55c99-dklc7         2/2     Running   0          4m15s
harbor-registry-d4df55c99-hhkhq         2/2     Running   0          4m15s
postgresql-ha-pgpool-86d7f66dbb-7t98j   1/1     Running   4          36h
postgresql-ha-postgresql-0              1/1     Running   1          36h
postgresql-ha-postgresql-1              1/1     Running   2          36h
postgresql-ha-postgresql-2              1/1     Running   2          36h
redis-node-0                            2/2     Running   0          14m
redis-node-1                            2/2     Running   0          14m
redis-node-2                            2/2     Running   0          13m
```


