# 1. K8S ETCD 단편화 제거 (Defragmentation)
- ETCD 상 변경 된 정보들은 삭제 되는 것이 아닌 Revisioning 된다 해당 변경 사항은 히스토리가 버저닝되어 정보가 저장이 되는 것으로 추측되며 일정 시간 뒤 Compaction 기능을 통해 압축 됩니다.
- 단편화를 제거하게 된다면, kube-apiserver 재기동 시 저장된 ETCD 캐시가 자동으로 새로 고쳐질 때 메모리 소비가 크게 줄어들게 된다고 합니다.

## 1.1. ETCD단편화 제거 작업

### 1.1.1. Pod 상태 확인

- 작업 전 초기 Pod 상태 확인를 하여 Crash 난 상태의 Pod가 있는지 확인 합니다.

```
$ kubectl get pods -A | grep -i Running | grep -i Completed
```

### 1.1.2. ETCD CLI 확인

- Control Plance Node에 접속하여 ETCD 명령어가 정상적으로 수행 되는지 확인 합니다.

```
$ ETCDCTL_API=3 etcdctl member list --endpoints=https://127.0.0.1:2379 \
--cacert=/etc/ssl/etcd/ssl/ca.pem \
--cert=/etc/ssl/etcd/ssl/node-ip-10-250-200-180.ap-northeast-1.compute.internal.pem \
--key=/etc/ssl/etcd/ssl/node-ip-10-250-200-180.ap-northeast-1.compute.internal-key.pem
```

### 1.1.3. ETCD Member 중 Reader 확인

- 아래 명령어 수행으로 ETCD Member 중 Reader True 상태를 확인 합니다.

```
ETCDCTL_API=3 etcdctl endpoint status --cluster -w table --endpoints=https://127.0.0.1:2379 \
--cacert=/etc/ssl/etcd/ssl/ca.pem \
--cert=/etc/ssl/etcd/ssl/node-ip-10-250-200-180.ap-northeast-1.compute.internal.pem \
--key=/etc/ssl/etcd/ssl/node-ip-10-250-200-180.ap-northeast-1.compute.internal-key.pem
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|          ENDPOINT           |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.250.205.107:2379 | 65403b2a76e496d8 |  3.4.13 |   28 MB |      true |      false |      4657 |    6220878 |            6220878 |        |
| https://10.250.200.180:2379 | 83cc852743709a0f |  3.4.13 |   28 MB |     false |      false |      4657 |    6220878 |            6220878 |        |
| https://10.250.209.154:2379 | a9e6e0b3aae622fe |  3.4.13 |   28 MB |     false |      false |      4657 |    6220878 |            6220878 |        |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

### 1.1.4. ETCD Defragment 실행

Defragment the etcd member 반드시 Reader를 제외 한 Node 부터 순차적으로 작업해야 하며, 1분 정도의 단절이 있을 수 있음.
ETCDCTL_API=3 etcdctl --command-timeout=30s --endpoints=https://localhost:2379 defrag \
--cacert=/etc/ssl/etcd/ssl/ca.pem \
--cert=/etc/ssl/etcd/ssl/node-ip-10-250-200-180.ap-northeast-1.compute.internal.pem \
--key=/etc/ssl/etcd/ssl/node-ip-10-250-200-180.ap-northeast-1.compute.internal-key.pem


### 1.1.5.  ETCD 상태 재 확인

- ETCD 상태를 다시 확인하여 DB Size가 줄었는지 확인

```
ETCDCTL_API=3 etcdctl endpoint status --cluster -w table --endpoints=https://127.0.0.1:2379 \
--cacert=/etc/ssl/etcd/ssl/ca.pem \
--cert=/etc/ssl/etcd/ssl/node-ip-10-250-200-180.ap-northeast-1.compute.internal.pem \
--key=/etc/ssl/etcd/ssl/node-ip-10-250-200-180.ap-northeast-1.compute.internal-key.pem
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|          ENDPOINT           |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.250.205.107:2379 | 65403b2a76e496d8 |  3.4.13 |   28 MB |      true |      false |      4657 |    6227919 |            6227919 |        |
| https://10.250.200.180:2379 | 83cc852743709a0f |  3.4.13 |   14 MB |     false |      false |      4657 |    6227919 |            6227919 |        |
| https://10.250.209.154:2379 | a9e6e0b3aae622fe |  3.4.13 |   28 MB |     false |      false |      4657 |    6227919 |            6227919 |        |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

- 모든 Node 재설정 후 다시 확인 한 결과

```
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|          ENDPOINT           |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.250.205.107:2379 | 65403b2a76e496d8 |  3.4.13 |   13 MB |      true |      false |      4657 |    6228827 |            6228827 |        |
| https://10.250.200.180:2379 | 83cc852743709a0f |  3.4.13 |   14 MB |     false |      false |      4657 |    6228827 |            6228827 |        |
| https://10.250.209.154:2379 | a9e6e0b3aae622fe |  3.4.13 |   13 MB |     false |      false |      4657 |    6228827 |            6228827 |        |
+-----------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

### 1.1.6. Kubernetes API & Pod 장애 확인

- 작업 후 이상이 있는 Container가 존해하는지 재 확인 한다.

```
$ kubectl get pods -A | grep -i Running | grep -i Completed
```

### 1.1.7. Ingress, SVC 외부 Request 정상 동작 확인



