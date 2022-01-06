# Spring Cloud Gateway 주요 설정 (Kubernetes Service Discovery)

### 1. Maven Dependency
- 기본적으로 spring-cloud-starter-kubernetes-client-all를 설정하고 K8S 환경에 배포를 하면 모든 Service, Pod에 대한 Service Discovery 기능이 활성화 되고, Default coreDNS의 cluster.local을 참조하여 내부 DNS를 Query


```
<parent>
	<groupId>org.springframework.boot</groupId>
	<artifactId>spring-boot-starter-parent</artifactId>
	<version>2.6.2</version>
	<relativePath/> <!-- lookup parent from repository -->
</parent>

<description>Demo project for Spring Boot</description>
<properties>
	<java.version>1.8</java.version>
	<spring-cloud.version>2021.0.0</spring-cloud.version>
</properties>
	
<dependency>
	<groupId>org.springframework.cloud</groupId>
	<artifactId>spring-cloud-starter-gateway</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-kubernetes-client-all</artifactId>
</dependency>
<!-- https://mvnrepository.com/artifact/org.springframework.cloud/spring-cloud-loadbalancer -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-loadbalancer</artifactId>
</dependency>
```

### 2. Spring application.properties

```
spring.application.name: cloud-k8s-app-leedh
spring.cloud.kubernetes.discovery.all-namespaces=true
spring.cloud.kubernetes.discovery.include-not-ready-addresses=true
spring.cloud.kubernetes.loadbalancer.mode=service
spring.cloud.kubernetes.enabled=true

spring.cloud.gateway.discovery.locator.enabled=true
spring.cloud.gateway.discovery.locator.lower-case-service-id=true

management.endpoints.web.exposure.include=*
management.endpoint.restart.enabled=true
management.endpoint.gateway.enabled=true
 
spring.cloud.gateway.routes[0].id=client-service
spring.cloud.gateway.routes[0].uri=http://client-service:8080 # {SERVICE-NAME}:{SERVICE-PORT}
spring.cloud.gateway.routes[0].predicates[0]=Path=/client-service/**
```


### 3. Result
- 아래는 Gateway를 통하여 Client App에서 spring-cloud-starter-kubernetes-client-all를 통해 현재 K8S 상에서 배포 된 모든 Service를 GET 한 화면

![spring-cloud-gateway-for-k8s-1][spring-cloud-gateway-for-k8s-1]

[spring-cloud-gateway-for-k8s-1]:./images/spring-cloud-gateway-for-k8s-1.PNG
