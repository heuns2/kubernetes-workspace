

```
  inputs: |
    [INPUT]
        Name tail
        Path /var/log/containers/*{NAMESPACE_NAME}*.log
        multiline.parser docker, cri
        Tag kube.{NAMESPACE_NAME}.*
        Mem_Buf_Limit 5MB
        Skip_Long_Lines On

  filters: |
    [FILTER]
        Name kubernetes
        Match kube.{NAMESPACE_NAME}.*
        Merge_Log On
        Kube_Tag_Prefix kube.{NAMESPACE_NAME}.var.log.containers.
        Keep_Log Off
        K8S-Logging.Parser On
        K8S-Logging.Exclude Off

  outputs: |
    [OUTPUT]
        Name es
        Match kube.{NAMESPACE_NAME}.*
        Host elasticsearch-master
        Logstash_Format On
        Logstash_Prefix {NAMESPACE_NAME}
        Replace_Dots On
        Retry_Limit False
```
