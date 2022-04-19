# Kong Gateway Helm v3 Install

## Prerequisites
- A Kubernetes cluster, v1.19 or later
- `kubectl`  v1.19 or later
- (Enterprise only) A  `license.json`  file from Kong
- Helm 3
- 참고 자료: [Kong Docs](https://docs.konghq.com/gateway/2.7.x/install-and-run/helm/), [Kong Github](https://github.com/Kong/charts/blob/main/charts/kong/README.md)

## 1. Kong Gateway Helm Install

### 1.1. namespace 생성
- kong helm 설치 용 namespace 생성

```
$ kubectl create namespace kong
```

- Configmap과 같은 다른 방식으로 구성을 관리하지 않기 위해 Postgresql를 배포
- DB-less 모드는 특히 구성 업데이트에 더 많은 주의가 필요하기 때문에 데이터베이스를 사용하는 것을 선호
- Postgresql Secret 생성

```
$ cat postgres-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: kong-postgresql
  namespace: kong
data:
  postgresql-password: a29uZw== # echo 'kong' | base64

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
         - "worker"
         - "infra"
         - "controlplane"
nodeSelector:
  role: "router"
tolerations:
- key: router-node
  operator: Exists
```

- Helm CLI를 통한 Kong Gateway 배포

```
$ helm upgrade --install kong . -n kong \
--set replicaCount=2 \
--set env.pg_database=kong \
--set env.pg_host=kong-postgresql \
--set env.database=postgres \
--set env.pg_user=kong \
--set env.pg_password.valueFrom.secretKeyRef.name=kong-postgresql \
--set env.pg_password.valueFrom.secretKeyRef.key=postgresql-password \
--set postgresql.enabled=true \
--set postgresql.service.port=5432 \
--set postgresql.postgresqlUsername=kong \
--set postgresql.postgresqlDatabase=kong \
--set postgresql.existingSecret=kong-postgresql \
--set SVC.type=NodePort \
--set proxy.type=NodePort \
--set serviceMonitor.enabled=true \
--set admin.enabled=true \
--set admin.http.enabled=true \
--set admin.type=ClusterIP \
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
kong-kong-proxy            NodePort    10.xxx.xxx.xxx   <none>        80:xxx/TCP,443:xxx/TCP   24m
kong-postgresql            ClusterIP   10.xxx.xxx.xxx   <none>        5432/TCP                     24m
kong-postgresql-headless   ClusterIP   None            <none>        5432/TCP                     24m
```

- Request 수행 확인

```
$ curl http://10.xxx.xxx.xxx:xxx
{"message":"no Route matched with those values"}

$ curl https://10.xxx.xxx.xxx:xxx -k
{"message":"no Route matched with those values"}
```


