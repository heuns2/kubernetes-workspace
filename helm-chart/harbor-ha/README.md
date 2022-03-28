
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
$ helm search repo bitnami/redis-cluster --versions

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
  tolerations:
  - key: storage-node
    operator: Exists

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
  tolerations:
  - key: storage-node
    operator: Exists

# value.yaml에 아래 라인 변경
  accessModes:
    - ReadWriteMany


# Reids Cluster Install
$ helm install redis-cluster . --namespace harbor \
--set global.storageClass=ceph-filesystem \
-f values.yaml,affinity-values.yaml

# Pod 형상 확인
$ kubectl -n harbor get pods
NAME              READY   STATUS    RESTARTS   AGE
redis-cluster-0   1/1     Running   0          2m7s
redis-cluster-1   1/1     Running   0          2m7s
redis-cluster-2   1/1     Running   0          2m7s
redis-cluster-3   1/1     Running   0          2m7s
redis-cluster-4   1/1     Running   0          2m7s
redis-cluster-5   1/1     Running   0          2m7s

# Reids Password 확인
$ kubectl get secret --namespace "harbor" redis-cluster -o jsonpath="{.data.redis-password}" | base64 --decode
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
--set redis.external.addr="redis-cluster.harbor.svc.cluster.local" \
--set redis.external.password="wrH7fQGVf5" \
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


-- Create required databases
CREATE DATABASE notaryserver;
CREATE DATABASE notarysigner;
CREATE DATABASE registry ENCODING 'UTF8';
CREATE DATABASE clair;

-- Create harbor user
-- The helm chart limits us to a single user for all databases
CREATE USER harbor;
ALTER USER harbor WITH ENCRYPTED PASSWORD 'change-this-password';

-- Grant the user access to the DBs
GRANT ALL PRIVILEGES ON DATABASE notaryserver TO harbor;
GRANT ALL PRIVILEGES ON DATABASE notarysigner TO harbor;
GRANT ALL PRIVILEGES ON DATABASE registry TO harbor;
GRANT ALL PRIVILEGES ON DATABASE clair to clair;
```

