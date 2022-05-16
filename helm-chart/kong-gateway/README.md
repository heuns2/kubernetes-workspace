# Kong Gateway Helm v3 Install

## Prerequisites
- A Kubernetes cluster, v1.19 or later
- `kubectl`  v1.19 or later
- (Enterprise only) A  `license.json`  file from Kong
- Helm 3
- Kong Gateway Helm Chart는 Gitlab 2.yaml/kong에 존재 합니다.
- 참고 자료: [Kong Docs](https://docs.konghq.com/gateway/2.7.x/install-and-run/helm/), [Kong Github](https://github.com/Kong/charts/blob/main/charts/kong/README.md)
- Kong Postgresql DB 이중화 필요
- Configmap과 같은 다른 방식으로 구성을 관리하지 않기 위해 Postgresql를 배포
- DB-less 모드는 특히 구성 업데이트에 더 많은 주의가 필요하기 때문에 데이터베이스를 사용하는 것을 선호

## 1. Postgresql HA Helm Install
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
$ helm upgrade --install postgresql-ha . --namespace kong \
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
$ psql --host postgresql-ha-pgpool.kong.svc.cluster.local -U postgres -d postgres -p 5432

$ CREATE DATABASE kong ENCODING 'UTF8';
$ CREATE USER kong;
$ ALTER USER kong WITH ENCRYPTED PASSWORD '1q2w3e4r5t';

$ GRANT ALL PRIVILEGES ON DATABASE kong TO kong;

# Database 확인
$ \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges
-----------+----------+----------+-------------+-------------+-----------------------
 kong      | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =Tc/postgres         +
           |          |          |             |             | postgres=CTc/postgres+
           |          |          |             |             | kong=CTc/postgres
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 repmgr    | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(5 rows)
```

## 1. Kong Gateway Helm Install

### 1.1. namespace 생성

- Kong helm 설치 용 namespace 생성

```
$ kubectl create namespace kong
```

- Postgresql Postgresql Password Secret 생성

```
$ cat postgres-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: kong-postgresql
  namespace: kong
data:
  postgresql-password: MXEydzNlNHI1dAo=

$ kubectl apply -f postgres-secret.yaml
```


- Router Node에 배포 하기 위하여 Affinify 설정

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
nodeSelector:
  role: "worker"
tolerations:
- key: router-node
  operator: Exists
```

- Helm CLI를 통한 Kong Gateway 배포

```
$ helm upgrade --install kong . -n kong \
--set replicaCount=2 \
--set env.pg_database=kong \
--set env.pg_host=postgresql-ha-pgpool.kong.svc.cluster.local \
--set env.database=postgres \
--set env.pg_user=postgres \
--set env.pg_password.valueFrom.secretKeyRef.name=kong-postgresql \
--set env.pg_password.valueFrom.secretKeyRef.key=postgresql-password \
--set SVC.type=NodePort \
--set proxy.type=NodePort \
--set serviceMonitor.enabled=true \
--set admin.enabled=true \
--set admin.http.enabled=true \
--set admin.type=ClusterIP \
--set kong.ingressController.customEnv.TZ=Asia/Seoul \
--set kong.customEnv.TZ=Asia/Seoul \
-f values.yaml,affinity-values.yaml
```

- Kong Gateway 배포 확인

```
# Pod 상태 확인
$ kubectl -n kong get pods
NAME                                      READY   STATUS      RESTARTS   AGE
kong-kong-5cbdddd6c-4q9mm                 2/2     Running     1          7m54s
kong-kong-5cbdddd6c-59znw                 2/2     Running     1          8m24s
kong-kong-post-upgrade-migrations-kd9x5   0/1     Completed   0          8m24s
kong-kong-pre-upgrade-migrations-cwtqt    0/1     Completed   0          8m39s
kong-postgresql-0                         1/1     Running     0          24m

# Service 확인
$ kubectl -n kong get svc
NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
kong-kong-proxy            NodePort    xx.xxx.33.184   <none>        80:xxxxx/TCP,443:xxxxx/TCP   24m
kong-postgresql            ClusterIP   xx.xxx.58.140   <none>        5432/TCP                     24m
kong-postgresql-headless   ClusterIP   None            <none>        5432/TCP                     24m
```

- Postgresql 연동 확인, Database에 접속하여 Tables의 생성 유무 확인

```
postgres=# \l
 kong      | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =Tc/postgres         +
           |          |          |             |             | postgres=CTc/postgres+
           |          |          |             |             | kong=CTc/postgres
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 repmgr    | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres

$ \c kong
You are now connected to database "kong" as user "postgres".

$ \dt
                     List of relations
 Schema |             Name              | Type  |  Owner
--------+-------------------------------+-------+----------
 public | acls                          | table | postgres
 public | acme_storage                  | table | postgres
 public | basicauth_credentials         | table | postgres
 public | ca_certificates               | table | postgres
 public | certificates                  | table | postgres
 public | cluster_events                | table | postgres
 public | clustering_data_planes        | table | postgres
 public | consumers                     | table | postgres
 public | hmacauth_credentials          | table | postgres
 public | jwt_secrets                   | table | postgres
 public | keyauth_credentials           | table | postgres
 public | locks                         | table | postgres
 public | oauth2_authorization_codes    | table | postgres
 public | oauth2_credentials            | table | postgres
 public | oauth2_tokens                 | table | postgres
 public | parameters                    | table | postgres
 public | plugins                       | table | postgres
 public | ratelimiting_metrics          | table | postgres
 public | response_ratelimiting_metrics | table | postgres
 public | routes                        | table | postgres
 public | schema_meta                   | table | postgres
 public | services                      | table | postgres
 public | sessions                      | table | postgres
 public | snis                          | table | postgres
 public | tags                          | table | postgres
 public | targets                       | table | postgres
 public | ttls                          | table | postgres
 public | upstreams                     | table | postgres
 public | workspaces                    | table | postgres

```

- Request 수행 확인

```
$ curl http://xx.xx.xxx.155:32121
{"message":"no Route matched with those values"}

$ curl https://xx.xx.xxx.155:30801 -k
{"message":"no Route matched with those values"}
```


