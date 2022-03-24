
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
$ helm repo add rook-release https://charts.rook.io/release
$ helm pull rook-release/rook-ceph --version v1.8.6 --untar

# Storage Node Affinity 설정
discover:
  nodeAffinity: node-type=storage
csi:
  provisionerNodeAffinity: node-type=storage
  pluginNodeAffinity: node-type=storage
  rbdProvisionerNodeAffinity: node-type=storage
  rbdPluginNodeAffinity: node-type=storage
  cephFSProvisionerNodeAffinity: node-type=storage
  cephFSPluginNodeAffinity: node-type=storage
admissionController:
  nodeAffinity: node-type=storage
nodeSelector:
 node-type: storage


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
# Node Taint 설정
$ kubectl taint nodes controlpalne-prd-1 true:NoSchedule
$ kubectl taint nodes controlpalne-prd-2 true:NoSchedule
$ kubectl taint nodes controlpalne-prd-3 true:NoSchedule
$ kubectl taint nodes worker-prd-1 router-node=true:NoSchedule
$ kubectl taint nodes worker-prd-2 storage-node=true:NoSchedule
$ kubectl taint nodes worker-prd-3 storage-node=true:NoSchedule
$ kubectl taint nodes worker-prd-4 storage-node=true:NoSchedule

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
              operator: In
              values:
              - "storage"

# Node 선택 용도의 value 파일 생성
$ cat node-values.yaml
cephClusterSpec:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: "nodes"
        devices:
          - name: "xvdf"


$ helm upgrade --install --namespace rook-ceph rook-ceph-cluster \
   --set operatorNamespace=rook-ceph . \
   -f values.yaml,affinity-values.yaml,node-values.yaml 

# Pod 형상 확인


# Storage Class 확인

```

- Disk 확인

```
$ lsblk -f

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
