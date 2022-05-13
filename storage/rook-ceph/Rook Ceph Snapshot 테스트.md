# Rook Ceph Snapshot 테스트

- Kubernetes CSI를 활용하여 Ceph PVC를 Snapshot & Restore 하는 방안에 대하여 설명 합니다.

## Prerequisites
- CSI Snapshttor 관련 CRDs 파일 (Kubernetes Custom API Resource)
- Snapshot Class (Ceph Storage Class Snapshot 기능 연동)
- Snapshot Controller

## 1. Test Mysql 

### 1.1. Helm Mysql 설치

- Helm을 통하여 Mysql을 설치, 외부 접속을 위하여 NodePort 설정

```
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm upgrade --install test-mysql bitnami/mysql --set primary.service.type=NodePort --set auth.rootPassword=GAEajPg3lZ
```

### 1.2. Mysql 형상 확인 
- 설치 된 Mysql 형상이 Running 상태, SVC가 Node Port로 정상적으로 설치 되었는지 확인

```
$ kubectl get pods,svc
NAME               READY   STATUS              RESTARTS   AGE
pod/test-mysql-0   0/1     ContainerCreating   0          7s

NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
service/kubernetes            ClusterIP   10.xxx.xxx.xxx      <none>        443/TCP          34d
service/test-mysql            NodePort    10.xxx.xxx.xxx   <none>        3306:30645/TCP   7s
service/test-mysql-headless   ClusterIP   None            <none>        3306/TCP         7s
```

### 1.3. Mysql 접근 & 데이터 생성

- Mysql Password GET

```
$ kubectl get secret --namespace default test-mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode
```

- Mysql 접속

```
$ mysql -h 10.xx.xxx.xxx -P 30645 -uroot -p"GAEajPg3lZ"
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

- Volume Snapshot 관련 CRD 생성

```
$ kubectl apply -f  https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
$ kubectl apply -f  https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
$ kubectl apply -f  https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.2/client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.2/deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes-csi/external-snapshotter/release-4.2/deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml
```

- Ceph Block Storage 용 Snapshot Class 생성 (초기 1회 작업)

```
$ cat block-snapshotclass.yaml
---
# 1.17 <= K8s <= v1.19
# apiVersion: snapshot.storage.k8s.io/v1beta1
# K8s >= v1.20
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-rbdplugin-snapclass
driver: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: rook-ceph
deletionPolicy: Delete

$ kubectl apply -f block-snapshotclass.yaml
```

- Ceph File System Storage 용 Snapshot Class 생성 (초기 1회 작업)

```
$ cat fs-snapshotclass.yaml
---
# 1.17 <= K8s <= v1.19
# apiVersion: snapshot.storage.k8s.io/v1beta1
# K8s >= v1.20
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-fsplugin-snapclass
driver: rook-ceph.cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: rook-ceph
deletionPolicy: Delete

$ kubectl apply -f fs-snapshotclass.yaml
```

- Volume Snapshot Classes 확인

```
$ kubectl get volumesnapshotclasses.snapshot.storage.k8s.io
NAME                      DRIVER                          DELETIONPOLICY   AGE
csi-fsplugin-snapclass    rook-ceph.cephfs.csi.ceph.com   Delete           23s
csi-rbdplugin-snapclass   rook-ceph.rbd.csi.ceph.com      Delete           2m40s

```

## 2. Ceph Snapshot 테스트

### 2.1. Blob Storage

#### 2.1.1. Ceph Blob Storage Snapshot 생성

- PVC 확인

```
$ kubectl get pvc
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-test-mysql-0   Bound    pvc-d5e4e5c8-26dd-41ef-8662-0c3aca43b5f7   8Gi        RWO            ceph-block     2d23h
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

- Snapshot 확인 (이때 아래 READYTOUSE, RESTORESIZE 등에 대한 값들이 공백 일 경우 Snapshot이 제대로 이루어 지지 않은 것으로 판단 합니다.)

```
$ kubectl get volumesnapshot
NAME             READYTOUSE   SOURCEPVC           SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS             SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mysql-snapshot   true         data-test-mysql-0                           8Gi           csi-rbdplugin-snapclass   snapcontent-5a51a1c4-be7b-41a7-829f-6fb5ade0c090   5s             6s
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


#### 2.1.2. Snapshot을 기반으로 PVC 생성

- 생성 한 Snapshot을 기반으로 신규 PVC를 생성 합니다.

```
$ cat restore-mysql-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc-restore
spec:
  storageClassName: ceph-block
  dataSource:
    name: mysql-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi

$ kubectl apply -f restore-mysql-pvc.yaml


# 생성한 PVC 확인
$ kubectl get pvc
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-test-mysql-0   Bound    pvc-d5e4e5c8-26dd-41ef-8662-0c3aca43b5f7   8Gi        RWO            ceph-block     2d23h
mysql-pvc-restore   Bound    pvc-a87d1541-0583-49af-a171-e0ea2556cd87   10Gi       RWO            ceph-block     5s
```

#### 2.1.3. Snapshot PVC를 기반으로 Mysql 재 배포 & 데이터 확인

- Mysql Helm 삭제 후 Snapshot PVC를 지정하여 재 설치

```
$ helm delete test-mysql
$ helm upgrade --install test-mysql bitnami/mysql --set primary.service.type=NodePort --set primary.persistence.existingClaim=mysql-pvc-restore --set auth.rootPassword=GAEajPg3lZ
```

```
# 재설치 한 Mysql 정보를 확인하고 다시 접근합니다.
$ mysql -h 10.xx.xxx.xxx -P 32487 -uroot -p"GAEajPg3lZ"
$ show databases;
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

6 rows in set (0.00 sec)

$ use ceph_test;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed

show tables;
+-------------------------+
| Tables_in_ceph_test |
+-------------------------+
| test                    |
+-------------------------+
1 row in set (0.01 sec)

 select * from test;
+----+----------+
| id | name     |
+----+----------+
|  1 | ceph     |
+----+----------+
1 row in set (0.00 sec)
```



### 2.2. Filesystem Storage

#### Prerequisites
- Helm Mysql을 Ceph Filesystem Storage Class를 사용하여 배포하였고, Mysql에 접속하여 DB: ceph_test, TABLE: test, Column name=ceph를 생성
- ex)

```
$ helm upgrade --install test-mysql bitnami/mysql --set primary.service.type=NodePort --set auth.rootPassword=GAEajPg3lZ --set primary.persistence.accessModes={"ReadWriteMany"} --set primary.persistence.storageClass="ceph-filesystem"

$ mysql -h 10.xx.xxx.xxx -P 30605 -uroot -p"GAEajPg3lZ"
```

#### 2.2.1. Filesystem  Blob Storage Snapshot 생성

- PVC 확인

```
$ kubectl get pvc
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
data-test-mysql-0   Bound    pvc-f5ecc3fa-5d36-4ff5-b74b-cb806df1414d   8Gi        RWX            ceph-filesystem   6s
```

- PVC Snapshot 생성

```
$ cat fs-mysql-snapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: mysql-snapshot
spec:
  volumeSnapshotClassName: csi-fsplugin-snapclass
  source:
    persistentVolumeClaimName: data-test-mysql-0

$ kubectl apply -f fs-mysql-snapshot.yaml
```

- Snapshot 확인 (이때 아래 READYTOUSE, RESTORESIZE 등에 대한 값들이 공백 일 경우 Snapshot이 제대로 이루어 지지 않은 것으로 판단 합니다.)

```
$ kubectl get volumesnapshot
NAME             READYTOUSE   SOURCEPVC           SOURCESNAPSHOTCONTENT   RESTORESIZE   SNAPSHOTCLASS            SNAPSHOTCONTENT                                    CREATIONTIME   AGE
mysql-snapshot   true         data-test-mysql-0                           8Gi           csi-fsplugin-snapclass   snapcontent-0a5822aa-8d53-40f9-877e-1a027cca302c   4s             4s
```

- Mysql 데이터 삭제

```
drop database ceph_test;
show databases;
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


#### 2.2.2. Snapshot을 기반으로 PVC 생성

- 생성 한 Snapshot을 기반으로 신규 PVC를 생성 합니다.

```
$ cat fs-restore-mysql-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc-restore
spec:
  storageClassName: ceph-filesystem
  dataSource:
    name: mysql-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi

$ kubectl apply -f restore-mysql-pvc.yaml


# 생성한 PVC 확인
$ kubectl get pvc
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
data-test-mysql-0   Bound    pvc-f5ecc3fa-5d36-4ff5-b74b-cb806df1414d   8Gi        RWX            ceph-filesystem   6m23s
mysql-pvc-restore   Bound    pvc-e929da45-86ae-40a5-9eb1-f374736f3ea8   10Gi       RWX            ceph-filesystem   4s

```

#### 2.2.3. Snapshot PVC를 기반으로 Mysql 재 배포 & 데이터 확인

- Mysql Helm 삭제 후 Snapshot PVC를 지정하여 재 설치

```
$ helm delete test-mysql
$ helm upgrade --install test-mysql bitnami/mysql --set primary.service.type=NodePort --set auth.rootPassword=GAEajPg3lZ --set primary.persistence.accessModes={"ReadWriteMany"} --set primary.persistence.storageClass="ceph-filesystem" --set primary.persistence.existingClaim=mysql-pvc-restore
```

```
# 재설치 한 Mysql 정보를 확인하고 다시 접근합니다.
$ mysql -h 10.xx.xxx.xxx -P 32419 -uroot -p"GAEajPg3lZ"

MySQL [(none)]> show databases;
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
6 rows in set (0.00 sec)

MySQL [(none)]> use ceph_test;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MySQL [ceph_test]> show tables;
+---------------------+
| Tables_in_ceph_test |
+---------------------+
| test                |
+---------------------+
1 row in set (0.00 sec)

MySQL [ceph_test]> select * from test;
+----+------+
| id | name |
+----+------+
|  1 | ceph |
+----+------+
1 row in set (0.00 sec)
```



