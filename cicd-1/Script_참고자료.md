
- Persistence Disk 사용

```
persistentVolumeClaim(mountPath: '/root/.m2/repository', claimName: 'maven-pvc', readOnly: 'false')
```

- Host Name 등록

```
  hostAliases:
  - ip: "xx.xx.xxx.xxx"
    hostnames:
    - "xxx.xxx.com"
            """, 
            containers: [...
```
