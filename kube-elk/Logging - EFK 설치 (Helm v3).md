# Logging - EFK 설치 (Helm v3)

- 본 문서는 Kubernetes 환경에 Elastic Search, Fluentd,  Kibana를 Helm 형태로 배포하여 Pod의 Log를 확인하는 방안에 대해서 설명 합니다.
- 각 Component 별 용도는 다음과 같습니다. Fluentd는 각 Node에 Deamon Set 형태로 배포 되며 각 Node에서 발생하는 Container Log, Audit Log를 수집하고 Elastic Search에 Output 합니다. Elastic Search는 Index 형태로 Fleuntd에서 받은 Log Data를 저장/분석하는 쿼리는 제공 합니다. Kibana는 Elastic Search의 Data를 시각화 합니다.

-   실행 환경
    -   AWS EKS 구성
    -   Nginx Ingress 구성

## 1. EFK 설치

### 1.1. namespace 생성

- EKF Logging 관리용 Namespace 생성

```
$ kubectl create namespace logging
```

### 1.2. Helm 설정 Elastic Search  & Kibana & Fleuntd

#### 1.2.1. Elastic Search Helm 설정

-   Elastic Search 공식 Helm Repo 추가 & 동기화

```
$ helm repo add https://helm.elastic.co
$ helm repo update
```

- Elastic Search Helm Source Code 다운로드

```
$ helm pull elastic/elasticsearch --untar
```

#### 1.2.2. Kibana 설정

- Kibana Helm Source Code 다운로드 (Elastic Repo에 존재)

```
$ helm pull elastic/kibana --untar
```

#### 1.2.3. Fleuntd 설정

-   Fluentd 공식 Helm Repo 추가 & 동기화

```
$ helm repo add https://kokuwaio.github.io/helm-charts
$ helm repo update
```

- Fleuntd Helm Source Code 다운로드

```
$ helm pull kokuwa/fluentd-elasticsearch --untar
```

### 1.3. Helm Install Elastic & Kibana & Fleuntd

#### 1.3.1. Elastic Search Helm Install

- Elastic Search Helm Install 실행
- Elastic Node 3대를 특정 EKS Node 1대에만 배포하기 위하여 antiAffinityTopologyKey, antiAffinity의 설정을 변경, 변경하지 않으면 Default 3대의 Elastic Node가 같은 Host에 배치 되지 않고 Pending 상태에 걸릴 수 있음

```
$ helm upgrade --install elasticsearch . \
-n logging \
--set volumeClaimTemplate.resources.requests.storage=20Gi \
--set volumeClaimTemplate.storageClassName=gp2 \
--set antiAffinityTopologyKey=elasticsearch \
--set antiAffinity=soft \
```

#### 1.3.2. Kibana Helm Install

- Kibana Helm Install 실행

```
$ helm upgrade --install kibana . -n logging 
```

#### 1.3.3. Fleuntd Helm Install

- Fleuntd Helm Install 실행
- elasticsearch.hosts를 Elastic Search의 Service/Service Port로 입력

```
$ helm upgrade --install fluentd kokuwa/fluentd-elasticsearch -n eks-monitoring \
--set elasticsearch.hosts=["elasticsearch-master:9200"]
```

### 1.4. Ingress 설정

- Ingress 용 인증서 Secrect을 생성합니다.

```
$ kubectl create -n logging secret tls monitoring-tls --key eks.leedh.cloud.key --cert eks.leedh.cloud.crt
```

- Elastic Search, Kibana에 대한 Ingress를 설정 합니다.

```
# Kibana Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kibana-ingress
  namespace: logging
  annotations:
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  rules:
  - host: "kibana.eks.leedh.cloud"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: kibana-kibana
            port:
              number: 5601
  tls:
  - hosts:
    - kibana.eks.leedh.cloud
    secretName: logging-tls

# Elastic Search Ingress
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: elastic-ingress
  namespace: logging
  annotations:
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  rules:
  - host: "elastic.eks.leedh.cloud"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: elasticsearch-master
            port:
              number: 9200
  tls:
  - hosts:
    - elastic.eks.leedh.cloud
    secretName: logging-tls
```

## 2. Elastic Search - Kibana - Logging 설치 확인

- Kibana UI

![logging-efk-1][logging-efk-1]

[logging-efk-1]:./images/logging-efk-1.PNG

- Elastic Search UI

![logging-efk-2][logging-efk-2]

[logging-efk-2]:./images/logging-efk-2.PNG

- Logging 확인

![logging-efk-3][logging-efk-3]

[logging-efk-3]:./images/logging-efk-3.PNG


