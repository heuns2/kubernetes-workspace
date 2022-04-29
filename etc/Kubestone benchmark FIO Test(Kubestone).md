# Kubestone benchmark

- Kubestone는 Kubenetes 설치 의 성능을 평가할 수 있는 Benchmarking Operation Tool 입니다, sysbench, fio, ioping, drill 등 다양한 측정 항목이 존재합니다.

## Requirements

## 1. Benchmarking 설치

-  Benchmark Cluster에 Crds를 생성하여 Kubestone을 통해 실행 할 수 있습니다.

### 1.1. 설정
- Kubestone Operator 관련 Crds와 Deployment를 배포 합니다.

```
$ ./kustomize build github.com/xridge/kubestone/config/default?ref=v0.5.0 | sed "s/kubestone:latest/kubestone:v0.5.0/" | kubectl create -f -
```

- FIO 테스트 용 Yaml 파일 생성

```
$ ./kustomize build github.com/xridge/kubestone/config/samples/fio/overlays/pvc
apiVersion: perf.kubestone.xridge.io/v1alpha1
kind: Fio
metadata:
  name: fio-sample
spec:
  cmdLineArgs: --name=randwrite --iodepth=1 --rw=randwrite --bs=4m --size=256M
  image:
    name: xridge/fio:3.13
  volume:
    volumeSource:
      persistentVolumeClaim:
        claimName: {PVC}
```

- 사용

```
Random Read: --direct=1 --rw=randread --bs=4k --size=256M --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap
Random Write: --direct=1 --rw=randwrite --bs=4k --size=256M --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap
```


```
# PVC 생성 파일
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fio-pvc
spec:
  accessModes:
    - ReadWriteMany
  volumeMode: Filesystem
  resources:
    requests:
      storage: 10Gi
  storageClassName: "longhorn"

# FIO 측정 파일 (RAED)
apiVersion: perf.kubestone.xridge.io/v1alpha1
kind: Fio
metadata:
  name: fio-sample
spec:
  cmdLineArgs: --name=randwrite --direct=1 --rw=randread --bs=4k --size=256M --numjobs=16 --time_based --runtime=180 --group_reporting --norandommap
  image:
    name: xridge/fio:3.13
  volume:
    volumeSource:
      persistentVolumeClaim:
        claimName: "fio-pvc"
```

## 2. 테스트 결과


### 2.1. Longhorn (RMX)

- Read

```
randwrite: (groupid=0, jobs=16): err= 0: pid=16: Fri Apr 29 09:03:17 2022
  read: IOPS=18.0k, BW=70.4MiB/s (73.8MB/s)(12.4GiB/180002msec)
    clat (usec): min=171, max=221190, avg=886.37, stdev=1257.97
     lat (usec): min=171, max=221190, avg=886.50, stdev=1257.97
    clat percentiles (usec):
     |  1.00th=[  486],  5.00th=[  578], 10.00th=[  619], 20.00th=[  668],
     | 30.00th=[  701], 40.00th=[  734], 50.00th=[  758], 60.00th=[  799],
     | 70.00th=[  840], 80.00th=[  914], 90.00th=[ 1139], 95.00th=[ 1582],
     | 99.00th=[ 3261], 99.50th=[ 4228], 99.90th=[ 6783], 99.95th=[ 8094],
     | 99.99th=[14222]
   bw (  KiB/s): min=24992, max=86976, per=99.99%, avg=72106.18, stdev=590.03, samples=5749
   iops        : min= 6248, max=21744, avg=18026.09, stdev=147.50, samples=5749
  lat (usec)   : 250=0.01%, 500=1.30%, 750=45.38%, 1000=38.96%
  lat (msec)   : 2=11.36%, 4=2.40%, 10=0.57%, 20=0.02%, 50=0.01%
  lat (msec)   : 100=0.01%, 250=0.01%
  cpu          : usr=0.32%, sys=1.01%, ctx=3270052, majf=0, minf=518
  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=3245142,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=70.4MiB/s (73.8MB/s), 70.4MiB/s-70.4MiB/s (73.8MB/s-73.8MB/s), io=12.4GiB (13.3GB), run=180002-180002msec
```

- Write

```

```

### 2.2. Longhorn (RMO)
