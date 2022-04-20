# ETCD Backup Cronjob

- 특정 Etcd CLI가 Packaging 되어 있는 Docker Image를 생성하고 Cronjob을 통하여 ETCD를 Backup 하는 방안에 대하여 설명 합니다.


## 1. Docker Image 파일 생성

- Docker Image를 생성하여 Harbor 또는 Docker Hub에 Upload 합니다.

```
# Docker File 생성
FROM alpine:latest

ARG ETCD_VERSION=v3.4.13

ENV ETCDCTL_ENDPOINTS "https://127.0.0.1:2379"
ENV ETCDCTL_CACERT "/etc/kubernetes/pki/etcd/ca.crt"
ENV ETCDCTL_KEY "/etc/kubernetes/pki/etcd/healthcheck-client.key"
ENV ETCDCTL_CERT "/etc/kubernetes/pki/etcd/healthcheck-client.crt"

RUN apk add --update --no-cache bash ca-certificates tzdata openssl

RUN wget https://github.com/etcd-io/etcd/releases/download/${ETCD_VERSION}/etcd-${ETCD_VERSION}-linux-amd64.tar.gz \
 && tar xzf etcd-${ETCD_VERSION}-linux-amd64.tar.gz \
 && mv etcd-${ETCD_VERSION}-linux-amd64/etcdctl /usr/local/bin/etcdctl \
 && rm -rf etcd-${ETCD_VERSION}-linux-amd64*

ENTRYPOINT ["/bin/bash"]


$ docker build --build-arg=v3.4.13 -t leedh/etcd-backup:v3.4.13 .
```


## 2. Cronjob 파일 생성
- 매일 새벽 2시 Etcd Backup이 수행 되는 Cronjob 생성
- 1일 이상 지난 Etcd Backup 본은 삭제

```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: etcd-backup
  namespace: kube-system
spec:
  schedule: "0 2 * * *"
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 2
  concurrencyPolicy: Allow
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: etcd-backup
            image: etcd-backup:v3.4.13
            env:
            - name: ETCDCTL_API
              value: "3"
            - name: ETCDCTL_ENDPOINTS
              value: "https://127.0.0.1:2379"
            - name: ETCDCTL_CACERT
              value: "/etc/ssl/etcd/ssl/ca.pem"
            - name: ETCDCTL_CERT
              value: "/etc/ssl/etcd/ssl/member-node1.pem"
            - name: ETCDCTL_KEY
              value: "/etc/ssl/etcd/ssl/member-node1-key.pem"
            command: ["/bin/bash","-c"]
            args: ["etcdctl snapshot save /data/etcd-backup/etcd-snapshot-$(date +%Y-%m-%dT%H:%M).db"]
            volumeMounts:
            - mountPath: /etc/ssl/etcd/ssl
              name: etcd-certs
              readOnly: true
            - mountPath: /data/etcd-backup
              name: etcd-backup
            - mountPath: /etc/localtime
              name: local-timezone
          - name: demo-clean
            image: busybox
            args:
            - /bin/sh
            - -c
            - find /data/etcd-backup -type f -mtime +1 -exec rm {} \;
            volumeMounts:
            - mountPath: /data/etcd-backup
              name: etcd-backup

          restartPolicy: OnFailure
          hostNetwork: true
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                    - key: node-role.kubernetes.io/master
                      operator: Exists
          tolerations:
            - key: node-role.kubernetes.io/master
              effect: NoSchedule
              operator: Exists
            - key: node.kubernetes.io/memory-pressure
              effect: NoSchedule
              operator: Exists
          volumes:
          - name: etcd-certs
            hostPath:
              path: /etc/ssl/etcd/ssl
              type: Directory
          - name: etcd-backup
            hostPath:
              path: /data/etcd-backup
              type: DirectoryOrCreate
          - name: local-timezone
            hostPath:
              path: /usr/share/zoneinfo/Asia/Seoul
```
