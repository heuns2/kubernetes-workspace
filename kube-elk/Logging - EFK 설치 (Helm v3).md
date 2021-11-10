# Logging - EFK 설치 (Helm v3)

- 본 문서는 Kubernetes 환경에 Elastic Search, Fluentd,  Kibana를 Helm 형태로 배포하여 Pod의 Log를 확인하는 방안에 대해서 설명 합니다.
- 각 Component 별 용도는 다음과 같습니다. Fluentd는 각 Node에 Deamon Set 형태로 배포 되며 각 Node에서 발생하는 Container Log, Audit Log를 수집하고 Elastic Search에 Output 합니다. Elastic Search는 Index 형태로 Fleuntd에서 받은 Log Data를 저장/분석하는 쿼리는 제공 합니다. Kibana는 Elastic Search의 Data를 시각화 합니다.


## 


