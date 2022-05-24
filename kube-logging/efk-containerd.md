
- Fluent Bit Containerd를 사용 할 경우 아래 속성 추가

```
daemonSetVolumes:
  - name: varlog
    hostPath:
      path: /var/log
  - name: varlibdockercontainers
    hostPath: ## 삭제
      path: /var/lib/docker/containers ## 삭제
  - name: etcmachineid
    hostPath:
      path: /etc/machine-id
      type: File

daemonSetVolumeMounts:
  - name: varlog
    mountPath: /var/log
  - name: varlibdockercontainers ## 삭제
    mountPath: /var/lib/docker/containers ## 삭제
    readOnly: true ## 삭제
  - name: etcmachineid
    mountPath: /etc/machine-id
    readOnly: true
```

- 파싱 에러 발생 시 Output에 아래 속성 추가

```
  outputs: |
    [OUTPUT]
        Name es
        Match kube.*
        Host elasticsearch-master
        Logstash_Format On
        Replace_Dots On <<< 추가
        Retry_Limit False

    [OUTPUT]
        Name es
        Match host.*
        Host elasticsearch-master
        Logstash_Format On
        Logstash_Prefix node
        Replace_Dots On <<< 추가
        Retry_Limit False

```
