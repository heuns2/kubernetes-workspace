# Snapscheduler Helm v3 Install

- Snapscheduler를 Enable 하게 되면  Persistence Disk에 대한 Snapshot을 일정 별로 생성 할 수 있습니다.
- 각 Snapscheduler는 새 Snapshot을 생성해야 하는 빈도와 Snapshot에 대한 보존 정책을 명시 할 수 있습니다.
- Snapscheduler v3.0 설치를 기반으로 하였으며 Kubenetes Version은 v1.21.6입니다.
- [참고 자료](https://backube.github.io/snapscheduler/)

## 1. Snapscheduler Helm Install

- Snapscheduler 설치 용 Namespace 생성

```
$ kubectl create namespace backube-snapscheduler
```

- 특정 Node에 Snapscheduler를 배포 하기 위하여 Affinity를 설정

```
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: backube/snapscheduler-affinity
                operator: In
                values:
                  - manager
          topologyKey: kubernetes.io/hostname
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: role
          operator: NotIn
          values:
          - "controlplane"
nodeSelector:
  role: "worker"
```

- Helm 명령을 통한 Snapscheduler Install

```
$ helm upgrade --install -n backube-snapscheduler snapscheduler . \
--set replicaCount=2 \
-f values.yaml,affinity.yaml
```

- Helm을 통해 배포 된 Snapscheduler  Pod 확인

```
$ kubectl -n backube-snapscheduler get pods -o wide
NAME                             READY   STATUS    RESTARTS   AGE   IP               NODE                   NOMINATED NODE   READINESS GATES
snapscheduler-5dbf595d86-4wf78   2/2     Running   0          87s   xx.xxx.xxx.xxx   xxx   <none>           <none>
snapscheduler-5dbf595d86-ll9k6   2/2     Running   0          29s   xx.xxx.xxx.xxx    xxx   <none>           <none>

```

## 2. Snapscheduler 설정

- Snapscheduler Yaml 파일 설정


```
$ cat snapshot-scheduler.yaml
---
apiVersion: snapscheduler.backube/v1
kind: SnapshotSchedule
metadata:
  name: 4hourly
  namespace: default
spec:
  #claimSelector:
  #  matchLabels:
  #    "app": "test"
  disabled: false
  retention:
    expires: "168h"
    maxCount: 3
  schedule: "*/1 * * * *"
  snapshotTemplate:
    labels:
      default: default
    snapshotClassName: csi-rbdplugin-snapclass

$ kubectl apply -f snapshot-scheduler.yaml
```

- Snapscheduler 설정 확인

```
$ kubectl get snapshotschedules.snapscheduler.backube

NAME      SCHEDULE      MAX AGE   MAX NUM   DISABLED   NEXT SNAPSHOT
4hourly   */1 * * * *   168h      3         false      2022-05-16T08:32:00Z
```

- 생성 된 Volumesnapshot을 확인

```
$ kubectl get volumesnapshot
mysql-pvc-restore-4hourly-202205160834   true         mysql-pvc-restore                           10Gi          csi-fsplugin-snapclass    snapcontent-ddb5cbde-16cd-4197-8d2c-58f3dfa3e938   28s            29s
```



