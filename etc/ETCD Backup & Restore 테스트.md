# ETCD Backup & Restore 테스트

- Kuberspray로 구축 된 Multi Contolplane Node(ETCD 3EA) 구성의 Cluster를 Backup & Restore하는 방안에 대해서 설명 합니다.
- Cronjob으로 ETCD Backup을 Contolplane Node에 NAS Storage로 받고 있음으로 Snapshot을 Save하는 단계는 Skip 하였습니다.


### Backup 전 형상 확인

```
NAMESPACE                 NAME                                                    READY   STATUS             RESTARTS   AGE
argo                      pod/argocd-application-controller-0                     0/1     Pending            0          3d1h
argo                      pod/argocd-applicationset-controller-6748848f5f-bn9cl   0/1     Pending            0          3d1h
argo                      pod/argocd-dex-server-67cddd784c-d28tm                  0/1     Pending            0          3d1h
argo                      pod/argocd-notifications-controller-74867f9bc7-s58bd    0/1     Pending            0          3d1h
argo                      pod/argocd-redis-74c9457cc5-ldpft                       0/1     Pending            0          3d1h
argo                      pod/argocd-repo-server-55d4fd6ff7-hvvgp                 0/1     Pending            0          3d1h
argo                      pod/argocd-repo-server-55d4fd6ff7-wqbg2                 0/1     Pending            0          3d1h
argo                      pod/argocd-server-5d75d8c4bd-gwpsl                      0/1     Pending            0          3d1h
argo                      pod/argocd-server-5d75d8c4bd-hc8hr                      0/1     Pending            0          3d1h
cattle-fleet-system       pod/fleet-agent-8fcfb99b6-7xxxx                         1/1     Running            2          45h
cattle-resources-system   pod/rancher-backup-5c9c8d4648-6srrc                     1/1     Running            3          45h
cattle-system             pod/cattle-cluster-agent-86c4b5bb5d-mxck5               0/1     CrashLoopBackOff   16         45h
cattle-system             pod/cattle-cluster-agent-86c4b5bb5d-pmmp8               0/1     CrashLoopBackOff   16         45h
default                   pod/hi                                                  1/1     Running            0          65m
default                   pod/hi2                                                 1/1     Running            0          65m
default                   pod/hi3                                                 1/1     Running            0          65m
default                   pod/keycloak-b946fd675-ltscb                            1/1     Running            1          23h
ingress-nginx             pod/ingress-nginx-admission-create-r58hx                0/1     Completed          0          23h
ingress-nginx             pod/ingress-nginx-admission-patch-sm5px                 0/1     Completed          0          23h
ingress-nginx             pod/ingress-nginx-controller-9596689c-pvq7t             1/1     Running            1          23h
jenkins                   pod/default-9kqz4                                       0/1     Error              0          2d21h
jenkins                   pod/jenkins-0                                           2/2     Running            4          3d
keycloak                  pod/keycloak-0                                          0/1     CrashLoopBackOff   80         23h
keycloak                  pod/keycloak-postgresql-0                               0/1     Pending            0          23h
kube-system               pod/calico-kube-controllers-8575b76f66-68675            1/1     Running            20         8d
kube-system               pod/calico-node-5lhlf                                   1/1     Running            7          8d
kube-system               pod/calico-node-bbptf                                   1/1     Running            7          8d
kube-system               pod/calico-node-cn6sn                                   1/1     Running            6          8d
kube-system               pod/calico-node-nkj6w                                   1/1     Running            7          8d
kube-system               pod/coredns-8474476ff8-4psk6                            1/1     Running            3          3d
kube-system               pod/coredns-8474476ff8-p8kk2                            1/1     Running            3          3d
kube-system               pod/dns-autoscaler-7df78bfcfb-ws5dk                     1/1     Running            6          8d
kube-system               pod/kube-apiserver-node1                                1/1     Running            19         8d
kube-system               pod/kube-apiserver-node2                                1/1     Running            17         8d
kube-system               pod/kube-apiserver-node3                                1/1     Running            18         8d
kube-system               pod/kube-controller-manager-node1                       1/1     Running            10         8d
kube-system               pod/kube-controller-manager-node2                       1/1     Running            10         8d
kube-system               pod/kube-controller-manager-node3                       1/1     Running            12         8d
kube-system               pod/kube-proxy-7rtml                                    1/1     Running            3          3d
kube-system               pod/kube-proxy-9v9z9                                    1/1     Running            3          3d
kube-system               pod/kube-proxy-km2b4                                    1/1     Running            3          3d
kube-system               pod/kube-proxy-zf797                                    1/1     Running            3          3d
kube-system               pod/kube-scheduler-node1                                1/1     Running            8          8d
kube-system               pod/kube-scheduler-node2                                1/1     Running            12         8d
kube-system               pod/kube-scheduler-node3                                1/1     Running            11         8d
kube-system               pod/nginx-proxy-node4                                   1/1     Running            6          8d
kube-system               pod/nodelocaldns-qx6cl                                  1/1     Running            7          8d
kube-system               pod/nodelocaldns-v7txr                                  1/1     Running            7          8d
kube-system               pod/nodelocaldns-z2jmv                                  1/1     Running            6          8d
kube-system               pod/nodelocaldns-zw8bz                                  1/1     Running            7          8d
velero                    pod/velero-77cc47995f-kbzf5                             1/1     Running            3          40h

NAMESPACE       NAME                                         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
argo            service/argocd-application-controller        ClusterIP      10.233.38.25    <none>        8082/TCP                     3d1h
argo            service/argocd-applicationset-controller     ClusterIP      10.233.8.205    <none>        7000/TCP                     3d1h
argo            service/argocd-dex-server                    ClusterIP      10.233.31.140   <none>        5556/TCP,5557/TCP            3d1h
argo            service/argocd-redis                         ClusterIP      10.233.61.65    <none>        6379/TCP                     3d1h
argo            service/argocd-repo-server                   ClusterIP      10.233.22.158   <none>        8081/TCP                     3d1h
argo            service/argocd-server                        ClusterIP      10.233.12.6     <none>        80/TCP,443/TCP               3d1h
cattle-system   service/cattle-cluster-agent                 ClusterIP      10.233.44.235   <none>        80/TCP,443/TCP               2d17h
default         service/ingress-nginx-controller             LoadBalancer   10.233.41.228   <pending>     80:30788/TCP,443:30716/TCP   8d
default         service/ingress-nginx-controller-admission   ClusterIP      10.233.52.0     <none>        443/TCP                      8d
default         service/keycloak                             LoadBalancer   10.233.32.110   <pending>     8080:30522/TCP               23h
default         service/kubernetes                           ClusterIP      10.233.0.1      <none>        443/TCP                      8d
ingress-nginx   service/ingress-nginx-controller             NodePort       10.233.36.33    <none>        80:32648/TCP,443:30394/TCP   23h
ingress-nginx   service/ingress-nginx-controller-admission   ClusterIP      10.233.60.75    <none>        443/TCP                      23h
jenkins         service/jenkins                              ClusterIP      10.233.14.66    <none>        8080/TCP                     3d
jenkins         service/jenkins-agent                        ClusterIP      10.233.54.155   <none>        50000/TCP                    3d
keycloak        service/keycloak                             LoadBalancer   10.233.57.53    <pending>     80:30714/TCP,443:32196/TCP   23h
keycloak        service/keycloak-headless                    ClusterIP      None            <none>        80/TCP                       23h
keycloak        service/keycloak-postgresql                  ClusterIP      10.233.61.51    <none>        5432/TCP                     23h
keycloak        service/keycloak-postgresql-hl               ClusterIP      None            <none>        5432/TCP                     23h
kube-system     service/coredns                              ClusterIP      10.233.0.3      <none>        53/UDP,53/TCP,9153/TCP       8d
velero          service/velero                               ClusterIP      10.233.4.40     <none>        8085/TCP                     41h

NAMESPACE     NAME                          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
kube-system   daemonset.apps/calico-node    4         4         4       4            4           kubernetes.io/os=linux   8d
kube-system   daemonset.apps/kube-proxy     4         4         4       4            4           kubernetes.io/os=linux   8d
kube-system   daemonset.apps/nodelocaldns   4         4         4       4            4           kubernetes.io/os=linux   8d

NAMESPACE                 NAME                                               READY   UP-TO-DATE   AVAILABLE   AGE
argo                      deployment.apps/argocd-applicationset-controller   0/1     1            0           3d1h
argo                      deployment.apps/argocd-dex-server                  0/1     1            0           3d1h
argo                      deployment.apps/argocd-notifications-controller    0/1     1            0           3d1h
argo                      deployment.apps/argocd-redis                       0/1     1            0           3d1h
argo                      deployment.apps/argocd-repo-server                 0/2     2            0           3d1h
argo                      deployment.apps/argocd-server                      0/2     2            0           3d1h
cattle-fleet-system       deployment.apps/fleet-agent                        1/1     1            1           45h
cattle-resources-system   deployment.apps/rancher-backup                     1/1     1            1           45h
cattle-system             deployment.apps/cattle-cluster-agent               0/2     2            0           45h
default                   deployment.apps/keycloak                           1/1     1            1           23h
ingress-nginx             deployment.apps/ingress-nginx-controller           1/1     1            1           23h
kube-system               deployment.apps/calico-kube-controllers            1/1     1            1           8d
kube-system               deployment.apps/coredns                            2/2     2            2           8d
kube-system               deployment.apps/dns-autoscaler                     1/1     1            1           8d
velero                    deployment.apps/velero                             1/1     1            1           40h

NAMESPACE                 NAME                                                          DESIRED   CURRENT   READY   AGE
argo                      replicaset.apps/argocd-applicationset-controller-6748848f5f   1         1         0       3d1h
argo                      replicaset.apps/argocd-dex-server-67cddd784c                  1         1         0       3d1h
argo                      replicaset.apps/argocd-notifications-controller-74867f9bc7    1         1         0       3d1h
argo                      replicaset.apps/argocd-redis-74c9457cc5                       1         1         0       3d1h
argo                      replicaset.apps/argocd-repo-server-55d4fd6ff7                 2         2         0       3d1h
argo                      replicaset.apps/argocd-server-5d75d8c4bd                      2         2         0       3d1h
cattle-fleet-system       replicaset.apps/fleet-agent-75c89c49dd                        0         0         0       45h
cattle-fleet-system       replicaset.apps/fleet-agent-8fcfb99b6                         1         1         1       45h
cattle-resources-system   replicaset.apps/rancher-backup-5c9c8d4648                     1         1         1       45h
cattle-system             replicaset.apps/cattle-cluster-agent-64d67ff4b5               0         0         0       45h
cattle-system             replicaset.apps/cattle-cluster-agent-86c4b5bb5d               2         2         0       45h
default                   replicaset.apps/keycloak-b946fd675                            1         1         1       23h
ingress-nginx             replicaset.apps/ingress-nginx-controller-9596689c             1         1         1       23h
kube-system               replicaset.apps/calico-kube-controllers-8575b76f66            1         1         1       8d
kube-system               replicaset.apps/coredns-58594dcb7c                            0         0         0       8d
kube-system               replicaset.apps/coredns-759f6dfd48                            0         0         0       8d
kube-system               replicaset.apps/coredns-8474476ff8                            2         2         2       8d
kube-system               replicaset.apps/dns-autoscaler-7df78bfcfb                     1         1         1       8d
velero                    replicaset.apps/velero-77cc47995f                             1         1         1       40h

NAMESPACE   NAME                                             READY   AGE
argo        statefulset.apps/argocd-application-controller   0/1     3d1h
jenkins     statefulset.apps/jenkins                         1/1     3d
keycloak    statefulset.apps/keycloak                        0/1     23h
keycloak    statefulset.apps/keycloak-postgresql             0/1     23h

NAMESPACE     NAME                        SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
kube-system   cronjob.batch/etcd-backup   0 2 * * *   False     0        <none>          16h

NAMESPACE       NAME                                       COMPLETIONS   DURATION   AGE
ingress-nginx   job.batch/ingress-nginx-admission-create   1/1           6s         23h
ingress-nginx   job.batch/ingress-nginx-admission-patch    1/1           4s         23h
```

### 사전 작업
- Service 관련 Namespace 삭제

```
$ kubectl delete ns jenkins
$ kubectl delete ns argocd
$ kubectl delete ns argo
$ kubectl delete ns keycloak
$ kubectl delete ns velero
$ kubectl delete ns ingress-nginx

# 삭제 확인
$ kubectl get ns
NAME                          STATUS   AGE
cattle-fleet-system           Active   2d21h
cattle-impersonation-system   Active   2d22h
cattle-resources-system       Active   2d3h
cattle-system                 Active   2d22h
default                       Active   9d
kube-node-lease               Active   9d
kube-public                   Active   9d
kube-system                   Active   9d
local                         Active   2d1h

```


## 1. 모든 Contol Plane Node ETCD 설정

- 모든 Contol Plane Node의 ETCD를 Stop

```
$ systemctl stop etcd
$ systemctl status etcd
```

- 모든 Contol Plane Node의 ETCD Data를 Old로 변경하여 저장

```
$ mv /var/lib/etcd /var/lib/etcd.old/
```

## 2. 1번 Contol Plane Node ETCD  복구

- 1번 Node의 IP는 10.250.218.214
- Restore 명령을 통해 ETCD Backup File 복구
- Etcd의 주요 설정을 파악하는  /etc/etcd.env 파일에서 확인


```
$ ETCDCTL_API=3 etcdctl snapshot restore /data/etcd-backup/etcd-snapshot-2022-04-20T0.db --endpoints=https://127.0.0.1:2379 \
--data-dir=/var/lib/etcd \
--cert=/etc/ssl/etcd/ssl/ca.pem \
--key=/etc/ssl/etcd/ssl/member-node1.pem \
--cacert=/etc/ssl/etcd/ssl/member-node1-key.pem \
--name=etcd1 \
--initial-advertise-peer-urls="https://10.250.218.214:2380" \
--initial-cluster="etcd1=https://10.250.218.214:2380"
```

- /etc/etcd.env 수정

```
- ETCD_INITIAL_CLUSTER_STATE=new # 기존 existing 을 new로 변경 ( new로 설정하면 , 각 etcd의 토큰값을 새로 발급 됨 )
- ETCD_INITIAL_CLUSTER=etcd1=https://10.250.218.214:2380 # 자기 자신만 바라보게끔 변경
```

- etcd restart

-   변경한 설정을 바탕으로 etcd.service 시작

```
$ systemctl start etcd
$ systemctl status etcd
```
- 정상적으로 Running 상태 인지 확인

```
$ ETCDCTL_API=3 etcdctl --write-out=table member list --endpoints=https://127.0.0.1:2379 \
--cert=/etc/ssl/etcd/ssl/member-node1.pem \
--key=/etc/ssl/etcd/ssl/member-node1-key.pem \
--cacert=/etc/ssl/etcd/ssl/ca.pem 

+-----------------+---------+-------+-----------------------------+-----------------------------+------------+
|       ID        | STATUS  | NAME  |         PEER ADDRS          |        CLIENT ADDRS         | IS LEARNER |
+-----------------+---------+-------+-----------------------------+-----------------------------+------------+
| e01d37e9dfb1f6a | started | etcd1 | https://10.250.218.214:2380 | https://10.250.218.214:2379 |      false |
+-----------------+---------+-------+-----------------------------+-----------------------------+------------+
```

- 2번 Node를 추가 (etcd name: etcd2  ip: 10.250.215.144)

```
$ ETCDCTL_API=3 etcdctl member add etcd2 --peer-urls=https://10.250.215.144:2380 --endpoints=https://127.0.0.1:2379 \
--cert=/etc/ssl/etcd/ssl/member-node1.pem \
--key=/etc/ssl/etcd/ssl/member-node1-key.pem \
--cacert=/etc/ssl/etcd/ssl/ca.pem  \
--endpoints=https://127.0.0.1:2379

# 아래 결과를 복사
ETCD_NAME="etcd2"
ETCD_INITIAL_CLUSTER="etcd1=https://10.250.218.214:2380,etcd2=https://10.250.215.144:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.250.215.144:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
```

- 다시 Member List 확인

```
$ ETCDCTL_API=3 etcdctl --write-out=table member list --endpoints=https://127.0.0.1:2379 \
--cert=/etc/ssl/etcd/ssl/member-node1.pem \
--key=/etc/ssl/etcd/ssl/member-node1-key.pem \
--cacert=/etc/ssl/etcd/ssl/ca.pem 
+------------------+-----------+-------+-----------------------------+-----------------------------+------------+
|        ID        |  STATUS   | NAME  |         PEER ADDRS          |        CLIENT ADDRS         | IS LEARNER |
+------------------+-----------+-------+-----------------------------+-----------------------------+------------+
|  e01d37e9dfb1f6a |   started | etcd1 | https://10.250.218.214:2380 | https://10.250.218.214:2379 |      false |
| 7c983da88bfbf303 | unstarted |       | https://10.250.215.144:2380 |                             |      false |
+------------------+-----------+-------+-----------------------------+-----------------------------+------------+
```

## 3. 2번 Contol Plane Node ETCD  복구

- 1번 Node에서 Member 추가 후  복사한 Line을 2번 Node의 /etc/etcd.env에서 설정을 변경 한다.

```
ETCD_NAME="etcd2"
ETCD_INITIAL_CLUSTER="etcd1=https://10.250.218.214:2380,etcd2=https://10.250.215.144:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.250.215.144:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
```

- 2번 Node ETCD Restart

```
$ systemctl start etcd
$ systemctl status etcd
```

## 4. 1번 Contol Plane Node에서 2번 Node의 상태 확인 & 3번 Node ETCD를 Member Add

- 1번 Node에서 Member List 확인

```
$ ETCDCTL_API=3 etcdctl --write-out=table member list --endpoints=https://127.0.0.1:2379 --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem --cacert=/etc/ssl/etcd/ssl/ca.pem
+------------------+---------+-------+-----------------------------+-----------------------------+------------+
|        ID        | STATUS  | NAME  |         PEER ADDRS          |        CLIENT ADDRS         | IS LEARNER |
+------------------+---------+-------+-----------------------------+-----------------------------+------------+
|  e01d37e9dfb1f6a | started | etcd1 | https://10.250.218.214:2380 | https://10.250.218.214:2379 |      false |
| 7c983da88bfbf303 | started | etcd2 | https://10.250.215.144:2380 | https://10.250.215.144:2379 |      false |
+------------------+---------+-------+-----------------------------+-----------------------------+------------+
```

- 1번 Node에서 3번 Node를 추가, 3번 Node의 etcd name은 etcd3이며 ip는 10.250.226.204

```
$ ETCDCTL_API=3 etcdctl member add etcd3 --peer-urls=https://10.250.210.61:2380 \
--cert=/etc/ssl/etcd/ssl/member-node1.pem \
--key=/etc/ssl/etcd/ssl/member-node1-key.pem \
--cacert=/etc/ssl/etcd/ssl/ca.pem  \
--endpoints=https://127.0.0.1:2379
# 마찬가지로 아래 결과물 복사
Member 687c0130e8c88703 added to cluster 544168111325322b
ETCD_NAME="etcd3"
ETCD_INITIAL_CLUSTER="etcd1=https://10.250.218.214:2380,etcd3=https://10.250.210.61:2380,etcd2=https://10.250.215.144:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.250.210.61:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
```

- 1번 Node에서 현재 Member 확인

```
$ ETCDCTL_API=3 etcdctl --write-out=table member list --endpoints=https://127.0.0.1:2379 --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem --cacert=/etc/ssl/etcd/ssl/ca.pem
```


## 5. 3번 Contol Plane Node ETCD  복구


- 1번 Node에서 Member 추가 후  복사한 Line을 3번 Node의 /etc/etcd.env에서 설정을 변경 한다.

```
ETCD_NAME="etcd3"
ETCD_INITIAL_CLUSTER="etcd1=https://10.250.218.214:2380,etcd3=https://10.250.210.61:2380,etcd2=https://10.250.215.144:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.250.210.61:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
```

- 3번 Node ETCD Restart

```
$ systemctl start etcd
$ systemctl status etcd
```

## 6. 전체 Cluster 확인 1, 2번 Node의 /etc/etcd.env 설정 변경

- 1번 Node에서 Member 상태 확인

```
$ ETCDCTL_API=3 etcdctl --write-out=table member list --endpoints=https://127.0.0.1:2379 --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem --cacert=/etc/ssl/etcd/ssl/ca.pem
+------------------+---------+-------+-----------------------------+-----------------------------+------------+
|        ID        | STATUS  | NAME  |         PEER ADDRS          |        CLIENT ADDRS         | IS LEARNER |
+------------------+---------+-------+-----------------------------+-----------------------------+------------+
|  e01d37e9dfb1f6a | started | etcd1 | https://10.250.218.214:2380 | https://10.250.218.214:2379 |      false |
| 687c0130e8c88703 | started | etcd3 |  https://10.250.210.61:2380 |  https://10.250.210.61:2379 |      false |
| 7c983da88bfbf303 | started | etcd2 | https://10.250.215.144:2380 | https://10.250.215.144:2379 |      false |
+------------------+---------+-------+-----------------------------+-----------------------------+------------+

$ ETCDCTL_API=3 etcdctl --write-out=table endpoint status --cluster --endpoints=https://127.0.0.1:2379 --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem --cacert=/etc/ssl/etcd/ssl/ca.pem
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|          ENDPOINT           |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.250.218.214:2379 |  e01d37e9dfb1f6a |  3.4.13 |   18 MB |      true |      false |        82 |       5728 |               5728 |        |
|  https://10.250.210.61:2379 | 687c0130e8c88703 |  3.4.13 |   18 MB |     false |      false |        82 |       5728 |               5728 |        |
| https://10.250.215.144:2379 | 7c983da88bfbf303 |  3.4.13 |   18 MB |     false |      false |        82 |       5728 |               5728 |        |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

- 1번 Node 설정 변경

```
ETCD_NAME="etcd1"
ETCD_INITIAL_CLUSTER="etcd1=https://10.250.218.214:2380,etcd3=https://10.250.210.61:2380,etcd2=https://10.250.215.144:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.250.210.61:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
```

- 2번 Node 설정 변경

```
ETCD_NAME="etcd2"
ETCD_INITIAL_CLUSTER="etcd1=https://10.250.218.214:2380,etcd3=https://10.250.210.61:2380,etcd2=https://10.250.215.144:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.250.210.61:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
```

- 기능 테스트

```
$ kubectl run --image=nginx test-app
kubectl get pods
NAME                         READY   STATUS      RESTARTS   AGE
test-app                     1/1     Running     0          5s
```

### 삭제 된 Namespace 데이터들이 다시 들어왔는지 확인

```
NAMESPACE                 NAME                                                READY   STATUS              RESTARTS   AGE
argo                      argocd-application-controller-0                     0/1     Pending             0          3d5h
argo                      argocd-applicationset-controller-6748848f5f-bn9cl   0/1     Pending             0          3d5h
argo                      argocd-dex-server-67cddd784c-d28tm                  0/1     Pending             0          3d5h
argo                      argocd-notifications-controller-74867f9bc7-s58bd    0/1     Pending             0          3d5h
argo                      argocd-redis-74c9457cc5-ldpft                       0/1     Pending             0          3d5h
argo                      argocd-repo-server-55d4fd6ff7-hvvgp                 0/1     Pending             0          3d5h
argo                      argocd-repo-server-55d4fd6ff7-wqbg2                 0/1     Pending             0          3d5h
argo                      argocd-server-5d75d8c4bd-gwpsl                      0/1     Pending             0          3d5h
argo                      argocd-server-5d75d8c4bd-hc8hr                      0/1     Pending             0          3d5h
cattle-fleet-system       fleet-agent-8fcfb99b6-7xxxx                         1/1     Running             1          2d1h
cattle-resources-system   rancher-backup-5c9c8d4648-6srrc                     1/1     Running             0          2d1h
cattle-system             cattle-cluster-agent-86c4b5bb5d-mxck5               1/1     Running             8          2d1h
cattle-system             cattle-cluster-agent-86c4b5bb5d-pmmp8               1/1     Running             8          2d1h
default                   etcd-backup-27508440-qvtcw                          0/2     Pending             0          4m28s
default                   hi                                                  1/1     Running             0          29h
default                   keycloak-b946fd675-ltscb                            1/1     Running             0          28h
ingress-nginx             ingress-nginx-admission-create-r58hx                0/1     Completed           0          28h
ingress-nginx             ingress-nginx-admission-patch-sm5px                 0/1     Completed           0          28h
ingress-nginx             ingress-nginx-controller-9596689c-pvq7t             1/1     Running             0          28h
jenkins                   default-9kqz4                                       0/1     Error               0          3d1h
jenkins                   jenkins-0                                           2/2     Running             2          3d4h
keycloak                  keycloak-0                                          0/1     Running             58         28h
keycloak                  keycloak-postgresql-0                               0/1     Pending             0          28h
kube-system               calico-kube-controllers-8575b76f66-68675            1/1     Running             12         9d
kube-system               calico-node-5lhlf                                   1/1     Running             6          9d
kube-system               calico-node-bbptf                                   1/1     Running             6          9d
kube-system               calico-node-cn6sn                                   1/1     Running             0          8d
kube-system               calico-node-nkj6w                                   1/1     Running             6          9d
kube-system               coredns-8474476ff8-4psk6                            1/1     Running             1          3d5h
kube-system               coredns-8474476ff8-p8kk2                            1/1     Running             1          3d5h
kube-system               dns-autoscaler-7df78bfcfb-ws5dk                     1/1     Running             0          9d
kube-system               etcd-backup-27507417-p6xbr                          0/1     Completed           0          21h
kube-system               etcd-backup-27507418-kk4kd                          0/1     Completed           0          21h
kube-system               etcd-backup-27507419-zrchg                          0/1     Completed           0          21h
kube-system               etcd-backup-27507420-9r49n                          0/1     ContainerCreating   0          21h
kube-system               etcd-backup-27508685-z2s98                          0/1     Pending             0          4m28s
kube-system               etcd-backup-27508686-sjfd5                          0/1     Pending             0          3m46s
kube-system               etcd-backup-27508687-dbd9q                          0/1     Pending             0          2m46s
kube-system               etcd-backup-27508688-k9l57                          0/1     Pending             0          60s
kube-system               etcd-backup-27508689-np45h                          0/1     Pending             0          46s
kube-system               kube-apiserver-node1                                1/1     Running             63         9d
kube-system               kube-apiserver-node2                                1/1     Running             57         9d
kube-system               kube-apiserver-node3                                1/1     Running             58         9d
kube-system               kube-controller-manager-node1                       1/1     Running             9          9d
kube-system               kube-controller-manager-node2                       1/1     Running             9          9d
kube-system               kube-controller-manager-node3                       1/1     Running             16         9d
kube-system               kube-proxy-7rtml                                    1/1     Running             2          3d5h
kube-system               kube-proxy-9v9z9                                    1/1     Running             0          3d5h
kube-system               kube-proxy-km2b4                                    1/1     Running             2          3d5h
kube-system               kube-proxy-zf797                                    1/1     Running             2          3d5h
kube-system               kube-scheduler-node1                                1/1     Running             7          9d
kube-system               kube-scheduler-node2                                1/1     Running             17         9d
kube-system               kube-scheduler-node3                                1/1     Running             14         9d
kube-system               nginx-proxy-node4                                   1/1     Running             6          8d
kube-system               nodelocaldns-qx6cl                                  1/1     Running             6          9d
kube-system               nodelocaldns-v7txr                                  1/1     Running             6          9d
kube-system               nodelocaldns-z2jmv                                  1/1     Running             0          8d
kube-system               nodelocaldns-zw8bz                                  1/1     Running             6          9d
velero                    velero-77cc47995f-kbzf5                             1/1     Running             1          45h
[centos@ip-10-250-227-204 kubespray-2.17.1]$ kubectl get all
NAME                             READY   STATUS    RESTARTS   AGE
pod/etcd-backup-27508440-qvtcw   0/2     Pending   0          4m34s
pod/hi                           1/1     Running   0          29h
pod/keycloak-b946fd675-ltscb     1/1     Running   0          28h

NAME                                         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/ingress-nginx-controller             LoadBalancer   10.233.41.228   <pending>     80:30788/TCP,443:30716/TCP   8d
service/ingress-nginx-controller-admission   ClusterIP      10.233.52.0     <none>        443/TCP                      8d
service/keycloak                             LoadBalancer   10.233.32.110   <pending>     8080:30522/TCP               28h
service/kubernetes                           ClusterIP      10.233.0.1      <none>        443/TCP                      9d

NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/keycloak   1/1     1            1           28h

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/keycloak-b946fd675   1         1         1       28h

NAME                        SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
cronjob.batch/etcd-backup   0 2 * * *   False     1        4h9m            21h

NAME                             COMPLETIONS   DURATION   AGE
job.batch/etcd-backup-27508440   0/1           4m34s      4m34s
```
