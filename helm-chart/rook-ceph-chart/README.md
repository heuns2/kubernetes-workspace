
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
$ lsblk -f
NAME    FSTYPE LABEL UUID                                 MOUNTPOINT
xvda
└─xvda1 xfs          6cd50e51-cfc6-40b9-9ec5-f32fa2e4ff02 /
xvdf

# lvm2 Install
$ sudo yum install -y lvm2
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

- Disaster Recovery에 대한 복구 지원

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
# Node Taint 설정
$ kubectl taint nodes controlpalne-prd-1 true:NoSchedule
$ kubectl taint nodes controlpalne-prd-2 true:NoSchedule
$ kubectl taint nodes controlpalne-prd-3 true:NoSchedule
$ kubectl taint nodes worker-prd-1 router-node=true:NoSchedule
$ kubectl taint nodes worker-prd-2 storage-node=true:NoSchedule
$ kubectl taint nodes worker-prd-3 storage-node=true:NoSchedule
$ kubectl taint nodes worker-prd-4 storage-node=true:NoSchedule


$ helm repo add rook-release https://charts.rook.io/release
$ helm pull rook-release/rook-ceph --version v1.8.6 --untar

# Storage Node Affinity 설정

]$ cat affinity-values.yaml
discover:
  nodeAffinity: node-type=storage
  tolerations:
  - key: storage-node
    operator: Exists
csi:
  provisionerNodeAffinity: node-type=storage
  provisionerTolerations:
  - key: storage-node
    operator: Exists

  pluginNodeAffinity: node-type=storage
  pluginTolerations:
  - key: storage-node
    operator: Exists

  rbdProvisionerNodeAffinity: node-type=storage
  rbdProvisionerTolerations:
  - key: storage-node
    operator: Exists

  rbdPluginNodeAffinity: node-type=storage
  rbdPluginTolerations:
  - key: storage-node
    operator: Exists

  cephFSProvisionerNodeAffinity: node-type=storage
  cephFSProvisionerTolerations:
  - key: storage-node
    operator: Exists

  cephFSPluginNodeAffinity: node-type=storage
  cephFSPluginTolerations:
  - key: storage-node
    operator: Exists

admissionController:
  nodeAffinity: node-type=storage
  tolerations:
  - key: storage-node
    operator: Exists

nodeSelector:
 node-type: storage

tolerations:
- key: storage-node
  operator: Exists



# crds.enabled true 상태로 설치
$ kubectl create ns rook-ceph
$ helm upgrade --install rook-ceph --namespace rook-ceph . -f values.yaml,affinity-values.yaml

# Running 상태 확인
$ kubectl -n rook-ceph get pods -o wide
NAME                                  READY   STATUS    RESTARTS   AGE    IP            NODE           NOMINATED NODE   READINESS GATES
rook-ceph-operator-8678458494-4pz2g   1/1     Running   0          3m2s   10.233.87.9   worker-prd-4   <none>           <none>

```

###  1.2.2. Ceph Cluster Helm Chart

- rerequisites
	-   Kubernetes 1.13+
	-   Helm 3.x
	-   Preinstalled Rook Operator


- Ceph Cluster (Ceph Storage 설치)

```
$ helm pull rook-release/rook-ceph-cluster --version v1.8.6 --untar

# Storage Node Affinity 용도의 value 파일 생성
$ cat affinity-values.yaml
cephClusterSpec:
  placement:
    all:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
          - matchExpressions:
            - key: node-type
              operator: NotIn
              values:
              - "router"
              - "controlplane"
      tolerations:
      - key: storage-node
        operator: Exists

# value.yaml 수정


toolbox:
  enabled: true
  image: rook/ceph:v1.8.6
  tolerations:
  - key: storage-node
    operator: Exists
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-type
            operator: NotIn
            values:
            - "router"
            - "controlplane"

cephObjectStores:
  - name: ceph-objectstore
    # see https://github.com/rook/rook/blob/master/Documentation/ceph-object-store-crd.md#object-store-settings for available configuration
    spec:
      metadataPool:
        failureDomain: host
        replicated:
          size: 3
      dataPool:
        failureDomain: host
        erasureCoded:
          dataChunks: 2
          codingChunks: 1
      preservePoolsOnDelete: true
      gateway:
        port: 80
        # securePort: 443
        # sslCertificateRef:
        instances: 1
        placement:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: node-type
                  operator: NotIn
                  values:
                  - "router"
                  - "controlplane"
          tolerations:
          - key: storage-node
            operator: Exists

cephFileSystems:
  - name: ceph-filesystem
    # see https://github.com/rook/rook/blob/master/Documentation/ceph-filesystem-crd.md#filesystem-settings for available configuration
    spec:
      metadataPool:
        replicated:
          size: 3
      dataPools:
        - failureDomain: host
          replicated:
            size: 3
      metadataServer:
        activeCount: 1
        activeStandby: true
        placement:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
              - matchExpressions:
                - key: node-type
                  operator: NotIn
                  values:
                  - "router"
                  - "controlplane"
          tolerations:
          - key: storage-node
            operator: Exists


$ helm upgrade --install --namespace rook-ceph rook-ceph-cluster \
   --set operatorNamespace=rook-ceph . \
   -f values.yaml,affinity-values.yaml

# Pod 형상 확인
$ kubectl get pods -n rook-ceph
NAME                                                     READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-mmnpp                                   3/3     Running     3          65m
csi-cephfsplugin-provisioner-6cb8955dd-k5f48             6/6     Running     6          65m
csi-cephfsplugin-provisioner-6cb8955dd-vlgbj             6/6     Running     6          65m
csi-cephfsplugin-spp7r                                   3/3     Running     3          65m
csi-cephfsplugin-zpv4b                                   3/3     Running     3          65m
csi-rbdplugin-2hhq6                                      3/3     Running     3          65m
csi-rbdplugin-f6zsp                                      3/3     Running     3          65m
csi-rbdplugin-provisioner-5cd98bfdb4-6zxl8               6/6     Running     6          65m
csi-rbdplugin-provisioner-5cd98bfdb4-kl7sc               6/6     Running     6          65m
csi-rbdplugin-zv75b                                      3/3     Running     3          65m
rook-ceph-crashcollector-worker-prd-2-756f55cbdb-trpcq   1/1     Running     0          56m
rook-ceph-crashcollector-worker-prd-3-69c5f9cc8c-f4vcp   1/1     Running     0          58m
rook-ceph-crashcollector-worker-prd-4-77d55bc55b-9qc8g   1/1     Running     1          63m
rook-ceph-mds-ceph-filesystem-a-76765f8c8d-m4gp9         1/1     Running     1          58m
rook-ceph-mds-ceph-filesystem-b-c46bcc574-7j9g7          1/1     Running     1          58m
rook-ceph-mgr-a-5d9689467d-mvhq8                         1/1     Running     1          58m
rook-ceph-mon-a-7446649fcd-rrvbf                         1/1     Running     1          64m
rook-ceph-mon-b-785c4d8748-9wvbm                         1/1     Running     1          64m
rook-ceph-mon-c-58d748db87-cw2qv                         1/1     Running     1          64m
rook-ceph-operator-84bb595896-kt94d                      1/1     Running     2          66m
rook-ceph-osd-0-7cf7d4bb76-n8p8l                         1/1     Running     1          62m
rook-ceph-osd-1-7c748b447-lmxs7                          1/1     Running     1          62m
rook-ceph-osd-2-5c6f4c8489-92jb8                         1/1     Running     1          62m
rook-ceph-osd-prepare-worker-prd-2-ddcxt                 0/1     Completed   0          55m
rook-ceph-osd-prepare-worker-prd-3-vw9nx                 0/1     Completed   0          55m
rook-ceph-osd-prepare-worker-prd-4-hbvnh                 0/1     Completed   0          55m
rook-ceph-rgw-ceph-objectstore-a-5c777d8689-wq7zd        1/1     Running     0          58m
rook-ceph-tools-f8775877d-jppx6                          1/1     Running     0          41m


# Storage Class 확인
$ kubectl get storageclasses.storage.k8s.io
NAME                   PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
ceph-block (default)   rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   65m
ceph-bucket            rook-ceph.ceph.rook.io/bucket   Delete          Immediate           false                  65m
ceph-filesystem        rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           true                   65m
```

### 1.2.3. Dashboard 확인

- Rook Ceph 관리 Dashboard Ingress 생성

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rook-ceph-mgr-dashboard
  namespace: rook-ceph
  annotations:
    kubernetes.io/ingress.class: "nginx"
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/server-snippet: |
      proxy_ssl_verify off;
spec:
  tls:
   - hosts:
     - xxx-xxx.xxx.xxx.cloud
     secretName: ceph-tls
  rules:
  - host: xxx-xxx.xxx.xxx.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rook-ceph-mgr-dashboard
            port:
              name: https-dashboard
```


### 1.2.4. 

- ceph 명령어 확인

```
$ kubectl -n rook-ceph exec rook-ceph-tools-f8775877d-jppx6 -it -- sh
sh-4.4$ ceph status
  cluster:
    id:     66854258-cf89-4482-8a95-d506c0862278
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum a,c,b (age 2h)
    mgr: a(active, since 2h)
    mds: 1/1 daemons up, 1 hot standby
    osd: 3 osds: 3 up (since 2h), 3 in (since 2h)
    rgw: 1 daemon active (1 hosts, 1 zones)

  data:
    volumes: 1/1 healthy
    pools:   11 pools, 177 pgs
    objects: 414 objects, 97 KiB
    usage:   60 GiB used, 300 GiB / 360 GiB avail
    pgs:     177 active+clean

  io:
    client:   1.3 KiB/s rd, 170 B/s wr, 2 op/s rd, 0 op/s wr

sh-4.4$ ceph osd status
ID  HOST           USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE
 0  worker-prd-3  20.0G  99.9G      0        0       0        0   exists,up
 1  worker-prd-2  20.0G  99.9G      0        0       1        0   exists,up
 2  worker-prd-4  20.0G  99.9G      0        0       2      105   exists,up
sh-4.4$ ceph osd df
ID  CLASS  WEIGHT   REWEIGHT  SIZE     RAW USE  DATA     OMAP    META    AVAIL    %USE   VAR   PGS  STATUS
 1    ssd  0.09769   1.00000  120 GiB   20 GiB  3.5 MiB  11 KiB  29 MiB  100 GiB  16.69  1.00  177      up
 0    ssd  0.09769   1.00000  120 GiB   20 GiB  3.5 MiB  11 KiB  29 MiB  100 GiB  16.69  1.00  177      up
 2    ssd  0.09769   1.00000  120 GiB   20 GiB  3.5 MiB  11 KiB  29 MiB  100 GiB  16.69  1.00  177      up
                       TOTAL  360 GiB   60 GiB   10 MiB  35 KiB  87 MiB  300 GiB  16.69
MIN/MAX VAR: 1.00/1.00  STDDEV: 0
sh-4.4$ ceph osd utilization
avg 177
stddev 0 (expected baseline 10.8628)
min osd.0 with 177 pgs (1 * mean)
max osd.0 with 177 pgs (1 * mean)
sh-4.4$ ceph osd pool stats
pool device_health_metrics id 1
  nothing is going on

pool ceph-blockpool id 2
  nothing is going on

pool ceph-objectstore.rgw.control id 3
  nothing is going on

pool ceph-filesystem-metadata id 4
  client io 853 B/s rd, 1 op/s rd, 0 op/s wr

pool ceph-objectstore.rgw.meta id 5
  nothing is going on

pool ceph-filesystem-data0 id 6
  nothing is going on

pool ceph-objectstore.rgw.log id 7
  nothing is going on

pool ceph-objectstore.rgw.buckets.index id 8
  nothing is going on

pool ceph-objectstore.rgw.buckets.non-ec id 9
  nothing is going on

pool .rgw.root id 10
  nothing is going on

pool ceph-objectstore.rgw.buckets.data id 11
  nothing is going on

sh-4.4$ ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME              STATUS  REWEIGHT  PRI-AFF
-1         0.29306  root default
-3         0.09769      host worker-prd-2
 1    ssd  0.09769          osd.1              up   1.00000  1.00000
-5         0.09769      host worker-prd-3
 0    ssd  0.09769          osd.0              up   1.00000  1.00000
-7         0.09769      host worker-prd-4
 2    ssd  0.09769          osd.2              up   1.00000  1.00000
```
- Sample Pod 배포 

```
# rook-ceph-cluster 디렉토리
sample-blob.yaml # blob Storage 배포
sample-sharedfilesystem.yaml # sharedfilesystem File System 배포

# sample-sharedfilesystem는 Replica 구조에서 파일이 같이 사용 되는지 확인
```

