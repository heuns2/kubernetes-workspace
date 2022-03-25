# Longhorn Install

-   Kubernetes 클러스터의 분산 상태 저장 애플리케이션을 위한 Persistence Storage로 Longhorn 볼륨 사용
-   클라우드 공급자가 있거나 없이 Kubernetes 볼륨을 사용할 수 있도록 Blob Storage를 Longhorn 볼륨으로 분할
-   여러 노드와 데이터 센터에 걸쳐 블록 스토리지를 복제하여 가용성 향상
-   NFS 또는 AWS S3와 같은 외부 스토리지에 백업 데이터 저장
-   기본 Kubernetes 클러스터의 데이터를 두 번째 Kubernetes 클러스터의 백업에서 빠르게 복구할 수 있도록 클러스터 간 재해 복구 볼륨을 생성합니다.
-   볼륨의 반복적인 스냅샷을 예약하고 NFS 또는 S3 호환 보조 스토리지에 대한 반복적인 백업을 예약합니다.
-   백업에서 볼륨 복원
-   영구 볼륨을 중단하지 않고 Longhorn 업그레이드 가능

## Installation Requirements

-   Docker v1.13+
-   Kubernetes v1.14+.
-   `open-iscsi`  is installed, and the  `iscsid`  daemon is running on all the nodes. For help installing  `open-iscsi`
-   The host filesystem supports the  `file extents`  feature to store the data. Currently we support:
    -   ext4
    -   XFS
-   `curl`,  `findmnt`,  `grep`,  `awk`,  `blkid`,  `lsblk`  must be installed.
-   Mount propagation must be enabled.


- 환경 설정 검사

```
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/master/scripts/environment_check.sh | bash
```

- 필요한 Dependency 설치

```
$ yum install epel-release
$ yum install jq
$ yum install iscsi-initiator-utils
```

## 1.2. Longhorn Heml v3 Install

### 1.2.1. Longhorn  Helm Chart

- Helm Chart Download

```
$ helm repo add longhorn https://charts.longhorn.io
$ helm repo update
# 버전 확인
$ helm search repo longhorn/longhorn --versions

$ helm pull longhorn/longhorn --version 1.2.4 --untar
```
- Storage Node에 Longhorn을 배포 하기 위해  affinity 설정

```
$ cat affinity-values.yaml
longhornManager:
  tolerations:
  - key: storage-node
    operator: Exists
  nodeSelector:
    node-type: storage

longhornDriver:
  tolerations:
  - key: storage-node
    operator: Exists
  nodeSelector:
    node-type: storage

longhornUI:
  tolerations:
  - key: storage-node
    operator: Exists
  nodeSelector:
    node-type: storage
```


- Helm Chart Install

```
$ kubectl create namespace longhorn-system
$ helm upgrade --install longhorn . --namespace longhorn-system -f values.yaml,affinity-values.yaml

# 아래 Deployment, DeamonSet File들은 Storage Node 지정 할 경우 수동으로 tolerations을 생성해야 할 수 있다.
csi-attacher
csi-provisioner
csi-resize
csi-snapshotter
longhorn-csi-plugin
engine-image-ei
```


### 1.2.2. Longhorn  확인

- ReadWriteOnce Type

```
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-pod-pvc-longhorn
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: longhorn
---
kind: Pod
apiVersion: v1
metadata:
  name: my-csi-app-longhorn
spec:
  containers:
    - name: my-frontend
      image: busybox
      volumeMounts:
      - mountPath: "/data"
        name: my-volume
      command: [ "sleep", "1000000" ]
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
  tolerations:
  - key: storage-node
    operator: Exists
  volumes:
    - name: my-volume
      persistentVolumeClaim:
        claimName: csi-pod-pvc-longhorn
```

- ReadWriteMany Type

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhornfs-pvc-fs
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: longhorn
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-registry-longhorn
  labels:
    k8s-app: kube-registry
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 3
  selector:
    matchLabels:
      k8s-app: kube-registry
  template:
    metadata:
      labels:
        k8s-app: kube-registry
        kubernetes.io/cluster-service: "true"
    spec:
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
      tolerations:
      - key: storage-node
        operator: Exists

      containers:
      - name: registry-longhorn
        image: registry:2
        imagePullPolicy: Always
        resources:
          limits:
            cpu: 100m
            memory: 100Mi
        env:
        # Configuration reference: https://docs.docker.com/registry/configuration/
        - name: REGISTRY_HTTP_ADDR
          value: :5000
        - name: REGISTRY_HTTP_SECRET
          value: "Ple4seCh4ngeThisN0tAVerySecretV4lue"
        - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
          value: /var/lib/registry
        volumeMounts:
        - name: image-store
          mountPath: /var/lib/registry
        ports:
        - containerPort: 5000
          name: registry
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /
            port: registry
        readinessProbe:
          httpGet:
            path: /
            port: registry
      volumes:
      - name: image-store
        persistentVolumeClaim:
          claimName: longhornfs-pvc-fs
          readOnly: false
```

![long-horn-ui-1][long-horn-ui-1]

[long-horn-ui-1]:./images/long-horn-ui.PNG
