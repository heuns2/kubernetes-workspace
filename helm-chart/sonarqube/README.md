
# Sonarcube Helm Install

## Requirements
-   Kubernetes 1.19+
-   Helm 3.2.0+
-   PV provisioner support in the underlying infrastructure
-   ReadWriteMany volumes for deployment scaling

## 1. Sonarcube Helm Install

- Sonacube Helm Repo Add & Update

```
$ helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
$ helm repo update
```

- Sonarcube Helm Chart Download

```
# 설치 가능 버전 확인
$ helm search repo sonarqube/sonarqube --versions
$ helm pull sonarqube/sonarqube --version=2.0.0+248 --untar
```

- Affinity 설정

```
$ cat affinity-values.yaml
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
nodeSelector:
  node-type: "storage"
```

- Sonarcube 용 PVC 생성

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonarqubes-pvc
  namespace: sonarqube
spec:
  accessModes:
    - ReadWriteMany
  volumeMode: Filesystem
  resources:
    requests:
      storage: 20Gi
  storageClassName: "longhorn"
```

- Sonarcube JDBC 용 PVC 생성(Helm으로 생성이 안될 경우)

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-sonarqube-postgresql-0
  namespace: sonarqube
spec:
  accessModes:
    - ReadWriteMany
  volumeMode: Filesystem
  resources:
    requests:
      storage: 10Gi
  storageClassName: "longhorn"
```

- Sonarcube Helm Install

```
$ kubectl create ns sonarqube
$ helm upgrade --install sonarqube . --namespace=sonarqube \
--set persistence.enabled=true \
--set persistence.existingClaim=sonarqubes-pvc \
--set persistence.accessMode=ReadWriteMany \
--set postgresql.persistence.storageClass=longhorn \
--set postgresql.persistence.accessMode=ReadWriteMany \
-f values.yaml,affinity-values.yaml
```

- Sonarcube Ingress 설정

```
$ cat sonarcubes-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sonacubes-ingress
  namespace: sonarqube
  annotations:
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "8m"
spec:
  rules:
  - host: "sonacubes.heun.leedh.xyz"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: sonarqube-sonarqube
            port:
              number: 9000
              
```
