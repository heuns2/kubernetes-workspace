# Nginx Ingress Service Monitor

- Prometheus Exporter 기능이 활성화 된 Nginx Ingress Controller의 Metrics을 Service Monitor를 통하여 방출 하는 방안에 대해 설명 합니다.

## 1. Nginx Ingress Service Monitor 사용

### 1.1. Nginx Ingress Controller 설정 정보 확인

```
$ kubectl -n ingress-nginx get svc
NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
ingress-nginx-controller             ClusterIP   10.xxx.xxx.xxx   <none>        80/TCP,443/TCP   7d2h
ingress-nginx-controller-admission   ClusterIP   10.xxx.xxx.xxx   <none>        443/TCP          7d2h
ingress-nginx-controller-metrics     ClusterIP   10.xxx.xxx.xxx    <none>        10254/TCP        7d2h

# Service 정보 확인
$ kubectl -n ingress-nginx get svc ingress-nginx-controller-metrics -o yaml
spec:
  clusterIP: 10.xxx.xxx.xxx
  clusterIPs:
  - 10.xxx.xxx.xxx
  ports:
  - name: metrics
    port: 10254
    protocol: TCP
    targetPort: metrics

# Lable 추가
$ kubectl -n ingress-nginx label svc ingress-nginx-controller-metrics ingress-metrics: "true"
```

### 1.2. Nginx Ingress Controller Service Monitoring 생성


```
$ cat nginx-service-monitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx-controller-metrics
  namespace: monitoring 
  labels:
    release: prometheus # 해당 Label 반드시 필요
spec:
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
  selector:
    matchLabels:
      ingress-metrics: "true"
  namespaceSelector:
    matchNames:
      - ingress-nginx

$ kubectl apply -f nginx-service-monitor.yaml
```
