
# Rook Ceph Snapshot 테스트

## 1. Test Mysql 

### 1.1. Helm Mysql 설치

- Helm을 통하여 Mysql을 설치, 외부 접속을 위하여 NodePort 설정

```
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm upgrade --install test-mysql bitnami/mysql --set primary.service.type=NodePort
```


### 1.2. Mysql 형상 확인 
- 설치 된 Mysql 형상이 Running 상태, SVC가 NodePort로 정상적으로 설치 되었는지 확인

```
$ kubectl get pods,svc
NAME               READY   STATUS              RESTARTS   AGE
pod/test-mysql-0   0/1     ContainerCreating   0          7s

NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
service/kubernetes            ClusterIP   10.xxx.xxx.xxx      <none>        443/TCP          34d
service/test-mysql            NodePort    10.xxx.xxx.xxx   <none>        3306:30867/TCP   7s
service/test-mysql-headless   ClusterIP   None            <none>        3306/TCP         7s
```


### 1.3. Mysql 접근 & 데이터 생성

- Mysql Password GET

```
$ kubectl get secret --namespace default test-mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode
```

- Mysql 접속

```
$ mysql -h 10.xxx.xxx.xxx -P 30867 -uroot -p"GAEajPg3lZ"
```

- Mysql 데이터 생성

```
CREATE  DATABASE  ceph_test default CHARACTER SET UTF8;  
SHOW DATABASES;
+--------------------+
| Database           |
+--------------------+
| ceph_test          |
| information_schema |
| my_database        |
| mysql              |
| performance_schema |
| sys                |
+--------------------+


USE ceph_test;
CREATE  TABLE  test( id INT  PRIMARY KEY AUTO_INCREMENT, name VARCHAR(32) NOT NULL) ENGINE=INNODB; DESCRIBE test;
Query OK, 0 rows affected (0.15 sec)

+-------+-------------+------+-----+---------+----------------+
| Field | Type        | Null | Key | Default | Extra          |
+-------+-------------+------+-----+---------+----------------+
| id    | int         | NO   | PRI | NULL    | auto_increment |
| name  | varchar(32) | NO   |     | NULL    |                |
+-------+-------------+------+-----+---------+----------------+

INSERT INTO test (name) VALUES('ceph');
select * from test;
Query OK, 0 rows affected (0.10 sec)
+----+------+
| id | name |
+----+------+
|  1 | ceph |
+----+------+


```
### 1.4. Ceph Snapshot 생성 & Mysql Data 삭제

- Volume Snapshot 관련 CRD 생성 (초기 1회 작업)

```
$ kubectl create -f  https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
$ kubectl create -f  https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
$ kubectl create -f  https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
```

- Ceph 용 Snapshot Class 생성 (초기 1회 작업)

```
$ cat snapshotclass.yaml
---
# 1.17 <= K8s <= v1.19
# apiVersion: snapshot.storage.k8s.io/v1beta1
# K8s >= v1.20
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-rbdplugin-snapclass
driver: rook-ceph.rbd.csi.ceph.com # driver:namespace:operator
parameters:
  # Specify a string that identifies your cluster. Ceph CSI supports any
  # unique string. When Ceph CSI is deployed by Rook use the Rook namespace,
  # for example "rook-ceph".
  clusterID: rook-ceph # namespace:cluster
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: rook-ceph # namespace:cluster
deletionPolicy: Delete

$ kubectl apply -f snapshotclass.yaml
```

- Volume Snapshot Classes 확인

```
$ kubectl get volumesnapshotclasses.snapshot.storage.k8s.io
NAME                      DRIVER                       DELETIONPOLICY   AGE
csi-rbdplugin-snapclass   rook-ceph.rbd.csi.ceph.com   Delete           2s
```

- PVC 확인

```
$ kubectl get pvc
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-test-mysql-0   Bound    pvc-d5e4e5c8-26dd-41ef-8662-0c3aca43b5f7   8Gi        RWO            ceph-block     3h10m
```

- PVC Snapshot 생성

```
$ cat mysql-snapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-snapshot
spec:
  volumeSnapshotClassName: csi-rbdplugin-snapclass
  source:
    persistentVolumeClaimName: data-test-mysql-0

$ kubectl apply -f mysql-snapshot.yaml
```

- Mysql 데이터 삭제

```
drop database ceph_test;
show databases;
MySQL [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| my_database        |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
```


### 1.5. Snapshot을 기반으로 PVC 생성

- 생성 한 Snapshot을 기반으로 신규 PVC를 생성 합니다.

```

```

- Pod를 Delete 하여 재 실행

```
$ kubectl delete pod my-release-mysql-0 --force
# Mysql 접근
$ mysql -h xxx.xxx.xx.xxx -P 30194 -uroot -p"BybBsPszZo"
show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| longhorn_test      |
| my_database        |
| mysql              |
| performance_schema |
| sys                |
+--------------------+
6 rows in set (0.00 sec)

use longhorn_test;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed

show tables;
+-------------------------+
| Tables_in_longhorn_test |
+-------------------------+
| test                    |
+-------------------------+
1 row in set (0.01 sec)

 select * from test;
+----+----------+
| id | name     |
+----+----------+
|  1 | longhorn |
+----+----------+
1 row in set (0.00 sec)

```

