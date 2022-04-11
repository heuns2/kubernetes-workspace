# Longhorn Snapshot 테스트

## 1. Test Mysql 

### 1.1. Helm Mysql 설치

- Helm을 통하여 Mysql을 설치, 외부 접속을 위하여 NodePort 설정

```
$ helm repo add bitnami https://charts.bitnami.com/bitnami
$ helm upgrade --install my-release bitnami/mysql --set primary.service.type=NodePort
```


### 1.2. Mysql 형상 확인 
- 설치 된 Mysql 형상이 Running 상태, SVC가 NodePort로 정상적으로 설치 되었는지 확인

```
$ kubectl get all
NAME                      READY   STATUS    RESTARTS   AGE
pod/my-release-mysql-0    1/1     Running   0          11m

NAME                                TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/my-release-mysql            NodePort    xxx.xxx.xxx.xxx <none>        3306:30194/TCP   11m
service/my-release-mysql-headless   ClusterIP   None           <none>        3306/TCP         11m

NAME                                READY   AGE
statefulset.apps/my-release-mysql   1/1     11m
```


### 1.3. Mysql 접근 & 데이터 생성

- Mysql Password GET

```
$ kubectl get secret --namespace default my-release-mysql -o jsonpath="{.data.mysql-root-password}" | base64 --decode
```

- Mysql 접속

```
$ mysql -h xxx.xxx.xx.xxx -P 30194 -uroot -p"BybBsPszZo"
```

- Mysql 데이터 생성

```
CREATE  DATABASE  longhorn_test default CHARACTER SET UTF8;  
SHOW DATABASE:
+--------------------+
| Database           |
+--------------------+
| information_schema |
| my_database        |
| mysql              |
| performance_schema |
| sys                |
+--------------------+

USE longhorn_test;
CREATE  TABLE  test( id INT  PRIMARY KEY AUTO_INCREMENT, name VARCHAR(32) NOT NULL) ENGINE=INNODB; DESCRIBE test;
INSERT INTO test (name) VALUES('longhorn');
select * from test;
Query OK, 0 rows affected (0.10 sec)

+-------+-------------+------+-----+---------+----------------+
| Field | Type        | Null | Key | Default | Extra          |
+-------+-------------+------+-----+---------+----------------+
| id    | int         | NO   | PRI | NULL    | auto_increment |
| name  | varchar(32) | NO   |     | NULL    |                |
+-------+-------------+------+-----+---------+----------------+

```

### 1.4. Longhorn Snapshot 생성 & Mysql Data 삭제

- Longhorn UI의 Volume 화면에서 Take Snapshot 버튼을 클릭하여 Snapshot을 생성

- Mysql 데이터 삭제

```
drop database longhorn_test;
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
```

### 1.5. Longhorn Snapshot을 통한 Disk Revert
- Longhorn Volume 화면에서 Node에서 Detach 하여 Maintance Mode를 활성화하고 다시 Attach
- Health 상태로 변경 되면 Snapshots을 선택하고 Revert 버튼을 클릭
- Longhorn Volume 화면에서 Node에서 Detach 하여 다시 Maintance Mode 모드를 비활성화 하고 PVC가 붙어 있는 Node에 Attach

### 1.6. Mysql Pod 재실행 및 데이터 확인

- Pod를 Delete하여 재 실행

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

