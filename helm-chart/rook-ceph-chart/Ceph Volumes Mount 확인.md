# Ceph Volumes Mount 연동

- Kubernetes Helm으로 설치 된 Ceph Storage를 사용하는 Host VM에서 Ceph Volume에 Mount하여 실제 PVC 데이터를 확인 하는 방안에 대하여 설명 합니다.
- Cluster IP를 공유하는 Kubernetes Cluster 내 모든 VM에서 사용이 가능 합니다.


## 1. Ceph 정보 확인

### 1.1. Ceph Volume Mount에 필요한 정보를 확인 합니다.

- Ceph Toolbox를 통하여 Admin Mount Secret 확인 (변경 되지 않는 정보임으로 1번만 기억 하면 됩니다.)

```
$ kubectl -n rook-ceph exec -it rook-ceph-tools-78dfbc8c45-t46rf -- cat /etc/ceph/keyring
[client.admin]
key = AQBKxxxxx==
```


-  pvc실제 경로 확인

1.  특정namespace의 특정 pod가 실행중인 node 확인
2.  해당namespace의 pvc이름 조회
3.  node서버 접속
4.  pvc이름으로 df -f | grep pvc이름

```
$ df -h | grep pvc-xxx-129e-450c-9e10-42711efd582a
10.xxx.x.xxx:6789,10.xxx.x.xxx:6789,10.xxx.x.xxx:6789:/volumes/csi/csi-vol-sadzxcd3da60-11ec-sad4-54713123zas/39e85e78-b2b0-4152-baf8-264c89a2ced4   30G  516M   30G   2% /var/lib/kubelet/plugins/kubernetes.io/csi/pv/pvc-xxx-129e-450c-9e10-42711efd582a/globalmount
10.xxx.x.xxx:6789,10.xxx.x.xxx:6789,10.xxx.x.xxx:6789:/volumes/csi/csi-vol-sadzxcd3da60-11ec-sad4-54713123zas/39e85e78-b2b0-4152-baf8-264c89a2ced4   30G  516M   30G   2% /var/lib/kubelet/pods/48d2e1e8-e17c-4bdd-8ccd-e41ce878ace7/volumes/kubernetes.io~csi/pvc-xxx-129e-450c-9e10-42711efd582a/mount
```

5.  실제 Ceph Volume 경로 확인

```
10.xxx.x.xxx:6789,10.xxx.x.xxx:6789,10.xxx.x.xxx:6789:/volumes/csi/csi-vol-sadzxcd3da60-11ec-sad4-54713123zas/39e85e78-b2b0-4152-baf8-264c89a2ced4
```


## 2. Ceph Volume Mount

- 실제 Ceph Mount 경로와 Secret 정보를 바탕으로 Host VM Filesystem에 Mount 합니다.

```
$ mkdir ceph-mnt
$ mount -t ceph 10.xxx.x.xxx:6789,10.xxx.x.xxx:6789,10.xxx.x.xxx:6789:/volumes/csi/csi-vol-sadzxcd3da60-11ec-sad4-54713123zas/39e85e78-b2b0-4152-baf8-264c89a2ced4 ceph-mnt -o name=admin,secret=AQBKxxxxx==
```

- Mount 정상화 확인

```
$ mount | grep joind
10.xxx.x.xxx:6789,10.xxx.x.xxx:6789,10.xxx.x.xxx:6789:/volumes/csi/csi-vol-sadzxcd3da60-11ec-sad4-54713123zas/39e85e78-b2b0-4152-baf8-264c89a2ced4 on /home/ubuntu/ceph-mnt type ceph (rw,relatime,name=admin,secret=<hidden>,acl,wsize=16777216)
```
