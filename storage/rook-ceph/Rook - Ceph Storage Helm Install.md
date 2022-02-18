# 1. Rook - Ceph Storage Helm Install

- Rook은 분산 스토리지 시스템을 자가 관리, 자가 확장, 자가 치유 스토리지 서비스로 전환합니다.
- 배포, 부트스트랩, 구성, 프로비저닝, 확장, 업그레이드, 마이그레이션, 재해 복구, 모니터링 및 리소스 관리와 같은 스토리지 관리자의 작업을 자동화 합니다.
- Rook은 Kubernetes 플랫폼의 기능을 사용하여 각 스토리지 제공 업체(Ceph, Cassandra, NFS)에 대해 Kubernetes Operator를 통해 서비스를 제공 합니다.
- Ceph는 Blob Storage, Object Storage 및 Shared File System을 위한 확장성이 뛰어난 분산 스토리지 솔루션

### Ceph Prerequisites
- Ceph Operator는 Kubernetes v1.16 이상을 지원
- Raw devices (no partitions or formatted filesystems)
- Raw partitions (no formatted filesystem)
- 블록 모드의 스토리지 클래스에서 사용 가능한 PV

```
# 아무것도 붙어 있지 않은 nvme1n1를 사용 예정
[ec2-user@ip-10-0-4-118 ~]$ lsblk -f
NAME          FSTYPE LABEL UUID                                 MOUNTPOINT
nvme1n1
nvme0n1
├─nvme0n1p1   xfs    /     a2d6f56b-f4f4-4d1a-8df1-9b20ffb3be14 /
└─nvme0n1p128
```

## 1.1. Ceph Storage

### 1.1.1. Design

- Rook을 사용하여 Kubenetes에서 Ceph 스토리지를 실행할 수 있으며, Ceph를 실행하여 Rook에서 관리하는 스토리지를 Kubenetes Pod에 Mount하거나 S3 API를 사용 할 수 있게 합니다.
- Rook Operator는 Storage 구성 요소의 구성을 자동화하고 클러스터를 모니터링하여 Storage가 사용 가능하고 정상 상태를 유지하는지 확인 합니다.
- Rook Operator는 Storage Cluster를 Bootstrap하고 모니터링하는 데 필요한 모든 것을 갖춘 간단한 Container 형태로 배포 됩니다.
- Rook Operator는 Ceph Monitor Pod(Health Check), RADOS(분산 스토리지) Storage를 제공하는 Ceph OSD Daemon, Ceph 관련 Daemon들을 실행하고 관리 합니다.
- Rook Operator는 서비스를 실행하는 데 필요한 포드 및 기타 리소스를 초기화하여 풀, 객체 저장소(S3/Swift) 및 파일 시스템에 대한 CRD를 관리합니다.

![rook-ceph-1][rook-ceph-1]

[rook-ceph-1]:./images/rook-ceph-1.PNG

- Rook Operator는 Cluster가 정상인지 확인하기 위해 Storage Deamon을 모니터링합니다.
- Ceph mons(모니터링 데몬)는 필요할 때 시작되거나 장애 조치되며 클러스터가 성장하거나 축소됨에 따라 기타 조정이 이루어집니다.
- Rook은 Storage를 Pod에 마운트하도록 Ceph-CSI 드라이버를 자동으로 구성합니다.

### 1.1.2. Ceph Storage 주요 특징

- Block Storage, Object Storage, Shared File System을 선택적으로 생성

- Ceph Dashboard와 Prometheus Monitoring 지원

- Disaster Recovery

- Ceph Cluster CRD
	- Ceph Cluster를 Host-based(VM Local Path), PVC-based Cluster(다른 Storage Claass를 이용 ex: aws ebs),  Stretch Cluster(확장 클러스터)로 생성 할 수 있습니다.

- Ceph Block Pool CRD
	1. Ceph Block Pool의 형태를 Ceph가 여러 노드에서 데이터의 전체 복사본을 생성하도록 Pool을 구성
	2. Hybrid Storage Pools(ex: HDD, SSD) 형태로 Disk Type을 혼합해서 사용하는 Hybrid Storage 형태로 Pool을 구성
	3. 제약 사항이 있지만 원본 데이터를 쪼개어 복제본을 만드는 Erasure Coded Pool 구성
	4. Ceph 클러스터 간에 Ceph 블록 장치 이미지를 비동기식으로 복제하는 프로세스 Mirroring 구성은 방식, 지리적으로 분산 되어 있어야 한다.
- ETC CRD
	- Object, NFS, File Shared System 등을 CRD로 변경 할 수 있습니다.


## 1.2. Rook Chef Heml v3 Install

### 1.2.1. Ceph Operator Helm Chart(Rook)

- Prerequisites
	- Kubernetes 1.13+
	- Helm 3.x

- Ceph Operator (Rook 설치)

```
$ helm repo add rook-release https://charts.rook.io/release
$ helm pull rook-release/rook-ceph --version v1.8.5 --untar

# crds.enabled true 상태로 설치
$ kubectl create ns rook-ceph
$ helm upgrade --install rook-ceph --namespace rook-ceph rook-ceph/ 

# Running 상태 확인
$ kubectl -n rook-ceph get pods
NAME                                  READY   STATUS    RESTARTS   AGE
rook-ceph-operator-64cfcd9954-q8rtg   1/1     Running   0          10m
```

###  1.2.2. Ceph Cluster Helm Chart

- rerequisites
	-   Kubernetes 1.13+
	-   Helm 3.x
	-   Preinstalled Rook Operator


- Ceph Cluster (Ceph Storage 설치)

```
$ helm pull rook-release/rook-ceph-cluster --version v1.8.5 --untar
$ helm upgrade --install --namespace rook-ceph rook-ceph-cluster \
   --set operatorNamespace=rook-ceph rook-ceph-cluster/

# Pod 형상 확인
$ kubectl -n rook-ceph get pods
NAME                                                              READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-98q7z                                            3/3     Running     0          32m
csi-cephfsplugin-dz7vl                                            3/3     Running     0          32m
csi-cephfsplugin-jln64                                            3/3     Running     0          32m
csi-cephfsplugin-lgh2p                                            3/3     Running     0          32m
csi-cephfsplugin-provisioner-6f54f6c477-hnjct                     6/6     Running     0          32m
csi-cephfsplugin-provisioner-6f54f6c477-llvvg                     6/6     Running     0          32m
csi-rbdplugin-bztwj                                               3/3     Running     0          32m
csi-rbdplugin-hl8cm                                               3/3     Running     0          32m
csi-rbdplugin-j4swm                                               3/3     Running     0          32m
csi-rbdplugin-l7bjd                                               3/3     Running     0          32m
csi-rbdplugin-provisioner-6d765b47d5-crtpm                        6/6     Running     0          32m
csi-rbdplugin-provisioner-6d765b47d5-j757v                        6/6     Running     0          32m
rook-ceph-crashcollector-7e55631978b6f3eea780498816038507-86xxd   1/1     Running     0          26m
rook-ceph-crashcollector-a887754a68b9b3e6275717ae0ee5eb16-q85nz   1/1     Running     0          27m
rook-ceph-crashcollector-af168ba018315187b0c104586ab1c589-cr9mk   1/1     Running     0          25m
rook-ceph-crashcollector-b01b03604001e907d874a6e4f8e6ed6a-vz4w4   1/1     Running     0          28m
rook-ceph-mds-ceph-filesystem-a-56f49ddc65-h5pz4                  1/1     Running     0          25m
rook-ceph-mds-ceph-filesystem-b-7f97564f7f-qndqd                  1/1     Running     0          25m
rook-ceph-mgr-a-84bc4c7799-bfjpt                                  1/1     Running     0          28m
rook-ceph-mon-a-6c855b699d-ghlgl                                  1/1     Running     0          32m
rook-ceph-mon-b-6d4d9768c4-jwbgd                                  1/1     Running     0          30m
rook-ceph-mon-c-5d45ddcd6b-psd47                                  1/1     Running     0          29m
rook-ceph-operator-64cfcd9954-q8rtg                               1/1     Running     0          47m
rook-ceph-osd-0-8fc85dd45-xt42f                                   1/1     Running     0          27m
rook-ceph-osd-1-77c6d8b65-f5zzv                                   1/1     Running     0          27m
rook-ceph-osd-2-d684bddc6-97m9j                                   1/1     Running     0          27m
rook-ceph-osd-3-67bdc56ff5-chxhd                                  1/1     Running     0          26m
rook-ceph-osd-prepare-7e55631978b6f3eea780498816038507-7rjp5      0/1     Completed   0          27m
rook-ceph-osd-prepare-a887754a68b9b3e6275717ae0ee5eb16-pmh9s      0/1     Completed   0          27m
rook-ceph-osd-prepare-af168ba018315187b0c104586ab1c589-xhbt8      0/1     Completed   0          27m
rook-ceph-osd-prepare-b01b03604001e907d874a6e4f8e6ed6a-lrctt      0/1     Completed   0          27m
rook-ceph-rgw-ceph-objectstore-a-77c4bbd7b-gljt4                  1/1     Running     0          24m

# Storage Class 확인
$ kubectl get storageclasses.storage.k8s.io
NAME                   PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
ceph-block (default)   rook-ceph.rbd.csi.ceph.com      Delete          Immediate              true                   34m
ceph-bucket            rook-ceph.ceph.rook.io/bucket   Delete          Immediate              false                  34m
ceph-filesystem        rook-ceph.cephfs.csi.ceph.com   Delete          Immediate              true                   34m
efs-sc                 efs.csi.aws.com                 Delete          Immediate              false                  30d
gp2 (default)          kubernetes.io/aws-ebs           Delete          WaitForFirstConsumer   true                   120d
```

- Disk 확인

```
$ -lsblk -f
NAME          FSTYPE      LABEL UUID                                   MOUNTPOINT
nvme1n1       LVM2_member       SQVIwJ-Q7lB-V5C7-9u2h-ApOm-dRKz-xj6dMW
└─ceph--aa909013--b9dd--4f21--92d7--7c8e03096946-osd--block--11a998b5--fe04--4c4a--98b9--15076ce51a8f
nvme0n1
├─nvme0n1p1   xfs         /     a2d6f56b-f4f4-4d1a-8df1-9b20ffb3be14   /
└─nvme0n1p128
```

