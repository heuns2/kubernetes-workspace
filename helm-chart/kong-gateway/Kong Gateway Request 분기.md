# Kong Gateway Request 분기

### Highlights
- Namespace - Namespace 간 격리는 변경 할 수는 없는 것으로 파악 됩니다.
- 각 Ingress 생성 시 Controller는 kong로 명시하게 되면 Kong Ingress Controller가 사용 됩니다.
- Konga UI 또는 Manifest에서 생성 된 Ingress 속성에 Plugin 설정을 편집하여 넣어서 반영을 시킵니다.
- Plugin 속성 중 Local  means the counter will be stored in memory.
- Plugin 속성 중 Cluster  means the kong database will store the counter.

```
$ kubectl get crd|grep konghq
kongclusterplugins.configuration.konghq.com           2022-04-19T04:29:04Z
kongconsumers.configuration.konghq.com                2022-04-19T04:29:04Z
kongingresses.configuration.konghq.com                2022-04-19T04:29:04Z
kongplugins.configuration.konghq.com                  2022-04-19T04:29:04Z
tcpingresses.configuration.konghq.com                 2022-04-19T04:29:04Z
udpingresses.configuration.konghq.com                 2022-04-19T04:29:04Z
```

## 1. Kong Gateway Request Ingress 생성

### 1.1. Sample App 준비

- Kong API Gateway 확인 용 v1, v2 App 배포

```
# Pod 생성
$ kubectl run --image=leedh/rolling-test:1.0 test-app-old --namespace=kong
$ kubectl run --image=leedh/rolling-test:2.0 test-app-new --namespace=kong

# Service 등록
$ kubectl -n kong expose pods test-app-new --type ClusterIP --name test-app-new --port 8080
$ kubectl -n kong expose pods test-app-old --type ClusterIP --name test-app-old --port 8080
```

- Kong API Gateway Ingress 생성 
	- kubernetes.io/ingress.class 지정 필요

```
$ cat kong-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kong-ingress
  namespace: kong
  annotations:
    kubernetes.io/ingress.class: "kong"
    konghq.com/strip-path: "true"
spec:
  ingressClassName: "kong"
  rules:
  - host: "xxx.leedh.xyz"
    http:
      paths:
      - pathType: Prefix
        path: /new
        backend:
          service:
            name: test-app-new
            port:
              number: 8080
      - pathType: Prefix
        path: /old
        backend:
          service:
            name: test-app-old
            port:
              number: 8080
  tls:
  - hosts:
    - xxx.leedh.xyz
```

### 1.2. UI 확인

- Kong을 통하여 정상적으로 2개의 Endpoint에 Request가 Proxy 되는지 확인


## 2. Kong Gateway Plugin 테스트

- [Kong Plugin](https://docs.konghq.com/hub/)

### 2.1. Basic Auth Test
- Konga UI 접속 -> [Routes] 버튼 클릭  -> [Edit] 버튼 클릭 -> [Plugin] 버튼 클릭 -> [Add Plugin] 버튼 클릭
- Authentication 화면에서 Basic Auth를 Add

- 해당 Route 경로에 Basic Auth 기능이 추가 되었는지 확인


### 2.1. IP Restriction Plugin 사용 (IP 제한 테스트)

- IP Restriction Plugin Config 설정하여 배포

```
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: ip-restriction
  namespace: kong
config: 
  allow:
  - xxx.xxx.xxx.xxx
plugin: ip-restriction
```

- Ingress annotations에 아래 라인 추가

```
konghq.com/plugins: "ip-restriction"
```

