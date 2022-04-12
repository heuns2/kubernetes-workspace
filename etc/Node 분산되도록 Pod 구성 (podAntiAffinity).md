- Node 분산되도록 Pod 구성 (podAntiAffinity)

```
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector:
      matchExpressions:
      - key: app.kubernetes.io/component
        operator: In
        values:
        - node
    topologyKey: "kubernetes.io/hostname"
```
