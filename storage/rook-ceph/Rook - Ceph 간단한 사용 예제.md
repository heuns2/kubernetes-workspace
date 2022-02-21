# 1. Rook - Ceph 간단한 사용 예제

- Rook Ceph 정상 설치 확인 용 Yaml 정리 본


## 1.1. Block Storage

### 1.1.1. Block Storage PVC, Pod 생성

```
# PVC 생성
$ cat pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-pod-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: ceph-block

# Pod 연동
$ cat pod.yaml
---
kind: Pod
apiVersion: v1
metadata:
  name: my-csi-app
spec:
  containers:
    - name: my-frontend
      image: busybox
      volumeMounts:
      - mountPath: "/data"
        name: my-volume
      command: [ "sleep", "1000000" ]
  volumes:
    - name: my-volume
      persistentVolumeClaim:
        claimName: csi-pod-pvc
```

## 1.2. Object Storage

### 1.2.1. Object Storage  버킷 생성, Object Put, Get

```
# 버킷 생성
$ cat bucket.yaml
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: ceph-bucket
spec:
  generateBucketName: ceph-bkt
  storageClassName: ceph-bucket

```

- UI에서 버킷 정보가 생성 되었는지 확인

![rook-ceph-bucket-1][rook-ceph-bucket-1]

[rook-ceph-bucket-1]:./images/rook-ceph-bucket-1.PNG

```
# 생성한 버킷에 정보 저장
mkdir ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = xxxxxx
aws_secret_access_key = xxxxxx
EOF

echo "Hello Rook" > /tmp/rookObj
./s5cmd --no-verify-ssl --endpoint-url https://rook-obj.eks.xxx.xxx cp /tmp/rookObj s3://ceph-bkt-5681bad7-8e34-4803-8c3a-2a59347507d0


./s5cmd --no-verify-ssl --endpoint-url https://rook-obj.eks.xxx.xxx cp s3://ceph-bkt-5681bad7-8e34-4803-8c3a-2a59347507d0/rookObj /tmp/rookObj-download
cat /tmp/rookObj-download
Hello Rook
```
