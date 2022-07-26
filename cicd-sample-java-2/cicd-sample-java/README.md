
# 파일구조

```
.
├── Dockerfile
├── Jenkinsfile
├── README.md
├── base
│   ├── deployment-bluegreen.yaml
│   ├── deployment.yaml
│   ├── kustomization.yaml
│   ├── service-bluegreen.yaml
│   └── service.yaml
├── cicd-template.yaml
├── helm-deployment
│   ├── Chart.yaml
│   ├── templates
│   │   ├── configmaps.yaml
│   │   ├── deployments.yaml
│   │   ├── ingress.yaml
│   │   └── service.yaml
│   └── values.yaml
├── images
│   ├── 1
│   └── micrometer.png
├── manifest
│   ├── dev
│   │   ├── deployment-bluegreen.yaml
│   │   ├── deployment-patch.yaml
│   │   ├── kustomization.yaml
│   │   ├── service-bluegreen.yaml
│   │   └── service-patch.yaml
│   └── prod
│       ├── deployment-patch.yaml
│       ├── kustomization.yaml
│       └── service-patch.yaml
├── mvnw
├── mvnw.cmd
├── my-tomcat
│   └── logs
│       └── access_log.2022-01-04.log
├── pom.xml
├── src
│   ├── main
│   │   ├── java
│   │   │   └── com
│   │   │       └── mzc
│   │   │           └── boot
│   │   │               └── SimpleBootApplication.java
│   │   └── resources
│   │       ├── application-kubernetes.yml
│   │       ├── application.yml
│   │       ├── bootstrap.yml
│   │       ├── elk.yml
│   │       └── promethues.txt
│   └── test
│       └── java
│           └── com
│               └── mzc
│                   └── boot
│                       └── SimpleBootApplicationTests.java
└── target
    ├── classes
    │   ├── application-kubernetes.yml
    │   ├── application.yml
    │   ├── bootstrap.yml
    │   ├── com
    │   │   └── mzc
    │   │       └── boot
    │   │           └── SimpleBootApplication.class
    │   ├── elk.yml
    │   └── promethues.txt
    ├── generated-sources
    │   └── annotations
    ├── generated-test-sources
    │   └── test-annotations
    ├── maven-status
    │   └── maven-compiler-plugin
    │       ├── compile
    │       │   └── default-compile
    │       │       ├── createdFiles.lst
    │       │       └── inputFiles.lst
    │       └── testCompile
    │           └── default-testCompile
    │               ├── createdFiles.lst
    │               └── inputFiles.lst
    ├── surefire-reports
    │   ├── TEST-com.mzc.boot.SimpleBootApplicationTests.xml
    │   └── com.mzc.boot.SimpleBootApplicationTests.txt
    └── test-classes
        └── com
            └── mzc
                └── boot
                    └── SimpleBootApplicationTests.class

```

