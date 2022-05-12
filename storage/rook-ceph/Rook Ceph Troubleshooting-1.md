# Rook Ceph Troubleshooting-1

### 상황 발생
- node1 VM의 Disk Device 삭제로 실제 사용 중이던 OSDs가 삭제되었고, 신규 node2 번의 OS Backup 본을 node1 VM에 복제하여 신규 Ceph Cluster가 깨진 현상이 발생
- node1의 OSDs 1, 3번은 Down 된 상태이며 이전 정보를 계속하여 찾고 있음
- 복구 시 약간의 전체적인 스토리지에서 읽어오는 Service에 대한 장애가 발생하고, 느려진 현상이 감지

- 주요 장애 Log 추출

```
2022-05-11 10:13:02.153365 I | clusterdisruption-controller: all "host" failure domains: [node1 node2 jv0597kubeinfradev03]. osd is down in failure domain: "". active node drains: false. pg health: "cluster is not fully clean. PGs: [{StateName:active+clean Count:164} {StateName:active+remapped+backfill_wait Count:9} {StateName:active+undersized+degraded+remapped+backfill_wait Count:3} {StateName:active+undersized+degraded+remapped+backfilling Count:1}]"
2022-05-11 10:13:04.346444 I | op-osd: OSD 2 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:05.379547 I | clusterdisruption-controller: all "host" failure domains: [node1 node2 jv0597kubeinfradev03]. osd is down in failure domain: "". active node drains: false. pg health: "cluster is not fully clean. PGs: [{StateName:active+clean Count:164} {StateName:active+remapped+backfill_wait Count:9} {StateName:active+undersized+degraded+remapped+backfill_wait Count:3} {StateName:active+undersized+degraded+remapped+backfilling Count:1}]"
2022-05-11 10:13:06.620357 I | op-osd: OSD 5 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:08.096798 I | op-osd: OSD 0 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:09.567460 I | op-osd: OSD 2 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:11.055557 I | op-osd: OSD 5 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:12.507270 I | op-osd: OSD 0 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:13.981725 I | op-osd: OSD 2 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:15.450691 I | op-osd: OSD 5 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:16.943700 I | op-osd: OSD 0 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:18.417081 I | op-osd: OSD 2 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:19.983728 I | op-osd: OSD 5 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:21.493463 I | op-osd: OSD 0 is not ok-to-stop. will try updating it again later
2022-05-11 10:13:22.987713 I | op-osd: OSD 2 is not ok-to-stop. will try updating it again later
```

### 조치 사항
- 장애가 발생한 node1 Node를 삭제 -> 재생성 후 node1의 Disk Device를 초기화, Rook Ceph Cluster를 초기화 후 자가 Repair를 실행


### 1. 장애 조치 상세 내역

#### 1.1. 장애 Node 제거

- Ansible 명령을 통하여 장애 Node를 제거합니다, 이때 Node를 삭제하면 해당 Node에 Kubelet, Kubeadm 등이 자동 삭제 됩니다.

```
$ ansible-playbook -i inventory/mycluster/inventory.ini remove-node.yml -b -v \
--private-key=~/.ssh/id_rsa --extra-vars "node=node1"
```

#### 1.2. 신규 Node 추가

- Ansible 명령을 통하여 신규 Node를 추가 합니다.

```
$ ansible-playbook -i inventory/mycluster/inventory.ini ./cluster.yml --flush-cache -v \
  --private-key=~/.ssh/id_rsa --become --become-user=root \
  -e kube_version=v1.21.6 -e container_manager=containerd -e  containerd_version=1.4.12 \
  -l node1
```
  
#### 1.3. Infra Node Label 생성

- Infra Node Label를 생성 합니다.

```
$ kubectl label node node1 role=infra
$ kubectl label node node1 node-type=storage
```

#### 1.4. Ceph Cluster 조정

- Rancher UI 또는 Edit 명령을 통하여 Rook Ceph Block, File System, Object Store의 replicated 3 -> 1개로 조정

```
$ kubectl -n rook-ceph edit cephblockpool
$ kubectl -n rook-ceph edit cephfilesystem
$ kubectl -n rook-ceph edit cephobjectstores
```

- Rancher UI 또는 Edit 명령을 통하여 Rook Ceph의 Rook-Ceph-Operator Deployment를 0개로 조정 합니다.

#### 1.5. Ceph 장애 OSD 축출 & Repair 수행
- Ceph Tool Box에 접근하여 장애 OSD를 제거하고 Repair 명령을 수행 합니다.

```
# rook-ceph 접근
$ kubectl -n rook-ceph exec rook-ceph-tools-78dfbc8c45-t46rf -it -- bash

# Down 상태의 OSDs 삭제, node1 Node의 장애 OSDs가 1,4번임으로 해당 번호를 삭제합니다.
$ ceph osd destroy 1 --yes-i-really-mean-it
$ ceph osd destroy 3 --yes-i-really-mean-it

# Clean 상태가 아닌 undersized, degraded, remapped 상태의 pg 들에 대하여 Repair 명령 실행 (약 20~30개 정도 진행)
$ ceph health detail
HEALTH_WARN mons a,b,c are low on available space
[WRN] MON_DISK_LOW: mons a,b,c are low on available space
    mon.a has 16% avail
    mon.b has 22% avail
    mon.c has 28% avail
    pg 1.1 undersized+degraded+remapped+backfill
    pg 2.1 undersized+degraded+remapped+backfill
    pg 3.1 undersized+degraded+remapped+backfill

$ ceph pg repair 1.1
$ ceph pg repair 2.1
$ ceph pg repair 3.1
```

#### 1.6. Ceph 초기화

- 장애 발생 node1  Node의 Ceph Device와 Rook 설정 파일 초기화 합니다.

```
# node1 Node가 사용 하는 Rook Ceph Device는 sda로 진행 하였습니다.

$ lsblk -f

$ sgdisk --zap-all "/dev/sda"
$ dd if=/dev/zero of="/dev/sda" bs=1M count=100 oflag=direct,dsync
$ partprobe /dev/sda


# 해당 파일이 존재 할 경우 실행
$ rm -rf /dev/ceph-*
# 해당 파일이 존재 할 경우 실행

$ rm -rf /dev/mapper/ceph--*

# 해당 파일이 존재 할 경우 실행, 삭제 또는 Old 로변경 가능
$ rm -rf /var/lib/rook
```

#### 1.7. Ceph 재배포

-  Rook Ceph Cluster Values Yaml 구성에 신규 Devices Name 등록하고 Rook Ceph를 배포 합니다.

```
    - name: "node1"
      devices:
      - name: "sda"
```

- Helm을 통하여  rook-ceph-cluster 배포 

```
$ helm upgrade --install --namespace rook-ceph rook-ceph-cluster \
--set operatorNamespace=rook-ceph . \
--set monitoring.enabled=true \
-f values.yaml,affinity-values.yaml
```

- Rancher UI 또는 Edit 명령을 통하여 Rook Ceph의 Rook-Ceph-Operator Deployment를 다시 1개로 조정 합니다.

#### 1.8. Ceph 정상화 확인

- Rook Ceph UI를 통하여 node1의 OSDs가 성공적으로 Running 상태인지 확인 합니다.
- node1의 OSDs가 성공적으로 Running라면 Rook Ceph Block, File System, Object Store의 replicated 1 -> 3개로 다시 조정합니다.

```
$ kubectl -n rook-ceph edit cephblockpool
$ kubectl -n rook-ceph edit cephfilesystem
$ kubectl -n rook-ceph edit cephobjectstores
```

- Rook Ceph UI Recovery Throughput이 동작하는지 확인 합니다.
