# SonarcubeHelm Install

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
$ helm search repo bitnami/sonarqube --versions
$ helm pull bitnami/sonarqube --version=1.0.3 --untar
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

- values.yaml ReadWriteMany 수정

```
  accessModes:
    - ReadWriteMany로 수정
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

- Sonarcube Helm Install

```
$ kubectl create ns sonarqube
$ helm upgrade --install sonarqube . --namespace=sonarqube \
--set global.storageClass=longhorn \
--set persistence.storageClass=longhorn \
--set service.type=ClusterIP \
--set persistence.existingClaim=sonarqubes-pvc \
--set sonarqubeUsername=admin \
--set sonarqubePassword=admin \
--set postgresql.persistence.accessMode=ReadWriteMany \
--set postgresql.auth.password="bn_sonarqube" \
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
spec:
  rules:
  - host: "sonacubes.heun.leedh.xyz"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: sonarqube
            port:
              number: 80
```
