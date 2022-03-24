# Nginx Ingress Helm Install

- 본 문서는 Nginx Ingress를 Helm Chart를 통하여 설치하는 방안에 대해 설명 합니다.
- 본 문서는 Nginx Ingress v1.0.0을 설치를 기반으로 합니다.


## 1. Nginx Ingress Helm Install

### 1.1. Helm Chart Repo 확인

```
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
$ helm repo update
```
- 설치 가능 버전 확인 및 Target Version 다운로드

```
$ helm search repo ingress-nginx/ingress-nginx --versions
$ helm pull ingress-nginx/ingress-nginx --version=4.0.12 --untar
```

### 1.2. Helm Nginx Install

- 특정 Router Node에 설치 되기 때문에 Anti Affinity, Node Selector 설정

```
$ cat affinity-values.yaml
controller:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "storage"
  nodeSelector:
    node-type: "router"
```

- Helm Install Ingress Controller

```
$ helm upgrade --install ingress-nginx . --namespace ingress-nginx \
--set controller.metrics.enabled=true \
--set controller.metrics.serviceMonitor.enabled=true \
--set controller.metrics.serviceMonitor.additionalLabels.release="prometheus" \
--set controller.service.type=NodePort \
-f values.yaml,affinity-values.yaml
```

### 1.3. Ingress Controller 설치 확인

```
# Pod Ruuning 확인
$ kubectl -n ingress-nginx get pods -o wide
NAME                                        READY   STATUS    RESTARTS   AGE   IP            NODE           NOMINATED NODE   READINESS GATES
ingress-nginx-controller-7fbc799c49-fhzw9   1/1     Running   0          70s   10.233.88.9   worker-prd-1   <none>           <none>

# Service 확인
$ kubectl -n ingress-nginx get svc -n ingress-nginx
NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    10.233.23.197   <none>        80:32192/TCP,443:31590/TCP   2m33s
ingress-nginx-controller-admission   ClusterIP   10.233.61.125   <none>        443/TCP                      2m33s
ingress-nginx-controller-metrics     ClusterIP   10.233.47.183   <none>        10254/TCP                    2m33s

# Request 확인
$ curl http://10.250.194.64:32192
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
$ curl https://10.250.194.64:31590 -k
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
```


