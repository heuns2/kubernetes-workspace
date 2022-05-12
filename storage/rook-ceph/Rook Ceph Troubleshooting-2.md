
# Rook Ceph Troubleshooting-2

### 상황 발생
- node2 재부팅 중 Device Name이 변경 되어 OSDs 0번이 Down, Out 된 현상이 발생

### 조치 사항
- Ceph Cluster가 DEGRADED를 자가 치유하도록 기다린 후에 모든 Pool이 active+clean 인 상황 일 때 Helm Chart의 Values Yaml의 설정을 변경하고 Helm을 재배포

### 1. 장애 조치 상세 내역

#### 1.1. Rook Ceph UI에서 상태 체크
- DEGRADED 상태의 Volume들이 active+clean 상태로 변경 되는 것을 확인 합니다.

#### 1.2.  Helm Value Yaml 설정 후 재배포
-   Rook Ceph Cluster Values Yaml 구성에 신규 Devices Name 등록하고 Rook Ceph를 배포 합니다.

```
    - name: "node2"
      devices:
      - name: "sda"
```

-   Helm을 통하여 rook-ceph-cluster 배포

```
$ helm upgrade --install --namespace rook-ceph rook-ceph-cluster \
--set operatorNamespace=rook-ceph . \
--set monitoring.enabled=true \
-f values.yaml,affinity-values.yaml
```

#### 1.3. 기존 잘 못된 Device를 찾는 디렉토리를 Old로 이동

- /var/lib/rook/rook-ceph로 이동하여 OSD 관리 디렉토리에서 block -> /dev/sda 잘 못된 Device의 정보를 갖고 있는 디렉토리를 Old로 변경 합니다.

```
-rw-------. 1 root root  152  5월 12 12:12 client.admin.keyring
drwxr-xr-x. 3  167  167   20  5월  4 16:45 crash
drwxr-xr-x. 2  167  167  129  5월 12 10:14 xxxx-xxxx-xxxx-xxxx-xxxx_38071dea-d723-4bab-8bbd-16624ce30342
drwxr-xr-x. 2  167  167  129  5월 12 12:21 xxxx-xxxx-xxxx-xxxx-xxxx_801d61b4-9c78-43f4-a9ae-bab71e4028bc
drwxr-xr-x. 2  167  167  129  5월 11 17:00 xxxx-xxxx-xxxx-xxxx-xxxx_801d61b4-9c78-43f4-a9ae-bab71e4028bc.old
drwxr-xr-x. 2  167  167   29  5월  4 16:45 log
-rw-r--r--. 1 root root  324  5월 12 12:12 rook-ceph.config
```

#### 1.4. OSD Pod 삭제
- 현재 장애가 발생하고 있는 OSD Pod를 강제 종료 합니다.
- 신규 OSD가 발생 하지 않을 경우 Rook-Ceph-Operator Deployment를 Rancher UI에서 재기동 합니다.


#### 1.5. Rook Ceph UI에서 상태 체크
- Missplaced 상태의 Volume들이 active+clean 상태로 변경 되는 것을 확인 합니다.
