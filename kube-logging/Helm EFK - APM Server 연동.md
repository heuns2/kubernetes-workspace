# Helm EFK - APM Server 연동
-  본 가이드는 Helm v3을 통하여 기존 EFK 시스템에 APM Server를 통합 연동 하고 K8S Spring Boot Java Sample App에 Elastic APM Agent를 배치하여 Kibana UI에서 확인 할 수 있는 방안에 대해 설명 합니다.
- Spring Boot Java Sample App을 설정하는 방안에 대해서는  Dockerfile을 통하여 생성하는 방안과 ElasticApmAttacher Class를 생성하여 설정하는 방안을 설명 합니다.
- Elastic Search, Kibana, APM Server 모두 v7.10.2를 사용합니다.

## 1.  APM Server 설치

### 1.1. APM Server Helm Install

- Helm을 통해 APM Server를 설치하기 위해 소스코드를 다운로드하고 EFK 시스템과 연동 할 수 있도록 values.yaml을 수정 합니다.

```
# helm source code 다운로드
$ helm pull elastic/apm-server --version 7.10.2 --untar

# APM Server source code 이동
$ cd apm-server/

# values.yaml 아래 코드 수정
apmConfig:
  apm-server.yml: |
    apm-server:
      host: "0.0.0.0:8200"
    queue: {}
    output.elasticsearch:
      hosts: ["http://elasticsearch-master:9200"]
    kibana:
      enabled: true
      host: "http://kibana-kibana:5601"
      setup.kibana.host: "kibana-kibana:5601"
      setup.kibana.protocol: "http"
      setup.kibana.path: /kibana
      setup.dashboards.enabled: true

# Ingress를 사용 할 것이면 아래 설정 추가
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
    # kubernetes.io/tls-acme: "true"
  path: /
  hosts:
    - apm-server.xxx.xxx.xxx
  tls: 
    - secretName: chart-example-tls
      hosts:
      - apm-server.xxx.xxx.xxx


```

- EFK가 설치 된 Namespace에 elm을 통해 APM Server를 설치 합니다.

```
$ helm upgrade --install apm-server-monitoring . --namespace="eks-monitoring"
```

- Pod의 Running 상태 정상 확인 후 Ingress URI 또는 Curl를 통하여 서비스 동작을 확인 합니다.

![elastic-apm-1][elastic-apm-1]

[elastic-apm-1]:./images/elastic-apm-1.PNG



## 2.  APM Agent 연동 (Java)

### 2.1. Maven Spring Boot APM Agent 배포

- Maven Spring Boot에서 소스 코드를 생성하여 APM Agent를 사용하는 방안입니다.

- pom.xml에 아래 Dependency 추가

```
</dependency>
<dependency>
    <groupId>co.elastic.apm</groupId>
    <artifactId>apm-agent-attach</artifactId>
    <version>1.28.3</version>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-elasticsearch</artifactId>
</dependency>
```

- ElasticAPMSetup.java, 해당 부분은 application.properties 정보로 대체하여 환경 변수에서 APM Server를 치환하여 이용이 가능 할 것 같습니다.

```
@Configuration
public class ElasticAPMSetup {
    private static final String SERVER_URL_KEY = "server_url";
    private static final String SERVICE_NAME_KEY = "service_name";
    private static final String SECRET_TOKEN_KEY = "secret_token";
    private static final String ENVIRONMENT_KEY = "environment";
    private static final String APPLICATION_PACKAGES_KEY = "application_packages";
    private static final String LOG_LEVEL_KEY = "log_level";

    @PostConstruct
    public void init() {
        Map<String, String> apmProps = new HashMap<>(6);
        apmProps.put(SERVER_URL_KEY, "http://apm-server.xxx.xxx.xxx");
        apmProps.put(SERVICE_NAME_KEY, "test-app");
        apmProps.put(SECRET_TOKEN_KEY, "");
        apmProps.put(ENVIRONMENT_KEY, "dev");
        apmProps.put(APPLICATION_PACKAGES_KEY, "com.mzc.boot");
        apmProps.put(LOG_LEVEL_KEY, "debug");
        ElasticApmAttacher.attach(apmProps);
    }
}
```


## 3.  APM Agent 연동 (Docker File)

### 3.1. DockerFile 연동 방안

- Docker Image를 생성 할 때 패키징 된 Jar 파일을 실행 시 APM Agent를 java 명령과 함께 배치하는 방안에 대해서 설명합니다.
- Docker File 예시

```
FROM openjdk:8-jdk-alpine
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar

ARG ELASTIC_FILE=elastic-apm-agent-1.28.3.jar
COPY ${ELASTIC_FILE} elastic-apm-agent-1.28.3.jar

CMD java -javaagent:/elastic-apm-agent-1.28.3.jar -Delastic.apm.service_name=leedh-service -Delastic.apm.application_packages=com.mzc.boot -Delastic.apm.server_url=http://apm-server.xxx.xxx.xxx-Delastic.apm.secret_token=  -jar /app.jar
```

- Docker Image 생성 후 Sample Pod 배포

```
$ docker build -t leedh/rolling-test:apm1.0.13 .

# Default Docker Hub에 Image Push
$ docker push leedh/rolling-test:apm1.0.13

# Sample Pod 생성
$ kubectl run --image=leedh/rolling-test:apm1.0.13 elastic-apm-agent

# 로그 확인 (Exception이 존재 하지 않는지)
$ kubectl logs elastic-apm-agent -f
```


## 4.  Kibana APM UI 확인

- Kibana APM UI에서 APM Agent가 배포 되어 있는 App을 확인

![elastic-apm-2][elastic-apm-2]

[elastic-apm-2]:./images/elastic-apm-2.PNG

- Kibana APM UI에서 APM Agent가 배포 되어 있는 App을 선택하여 상세 화면 확인 (TPS, Request Per Minute을 확인 할 수 있습니다.)


![elastic-apm-3][elastic-apm-3]

[elastic-apm-3]:./images/elastic-apm-3.PNG


- Kibana APM UI에서 Error Exception을 강제로 발생 시키고 확인해보면 어떤 Exception이 몇번 처리 되었는지 확인이 가능 하며, 각 Exception 별로 상세화면을 확인 할 수 있습니다.


![elastic-apm-3][elastic-apm-3]

[elastic-apm-3]:./images/elastic-apm-3.PNG


![elastic-apm-4][elastic-apm-4]

[elastic-apm-4]:./images/elastic-apm-4.PNG

![elastic-apm-5][elastic-apm-5]

[elastic-apm-5]:./images/elastic-apm-5.PNG



- Kibana APM UI에서 Java App의 간단한 JVM Heap, Non Heap 사용률과 가비지 컬렉션에 대한 정보를 확인 할 수 있습니다.

![elastic-apm-6][elastic-apm-6]

[elastic-apm-6]:./images/elastic-apm-6.PNG


