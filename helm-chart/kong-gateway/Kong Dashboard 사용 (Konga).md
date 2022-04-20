# Kong Dashboard 사용 (Konga)

## Kong Gateway 관리 Dashboard Konga 설치

https://github.com/pantsel/konga

- Konga Helm Install

```
$ helm  upgrade --install konga . -n kong
```

- Ingress 설정

```
$ cat konga-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: konga-ingress
  namespace: kong
  annotations:
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: "xxx.leedh.xyz"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: konga
            port:
              number: 80
  tls:
  - hosts:
    - xxx.leedh.xyz


$ kubectl apply -f konga-ingress.yaml
```
