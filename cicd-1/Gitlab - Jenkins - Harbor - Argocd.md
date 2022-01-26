# Gitlab - Jenkins - Harbor - Argocd
-   본 문서는 아래 절차에 대해서 설명 합니다.
	- Jenkins Pipeline를 통하여 Gitlab에서 Source Code Clone & Build
	- Build Image 생성
	- Build Image Harbor Upload
	
-   실행 환경
    - AWS EKS 구성
    - Nginx Ingress 구성
    - Jenkins v2.303.2 (Helm)
    - Harbor v2.2.4 (VM)
    - Gitlab v14.4.1(Helm)
    - Argocd v2.1.6(Helm)
    - Sample Source Code (https://github.com/heuns2/kubernetes-workspace/tree/main/cicd-sample-java)

- Jenkins 주요 Plugin 구성
	- Kubernetes
	- Git
	- Pipeline
	- Generic Webhook Trigger
	- Gitlab

- 각 Node에서 Harbor 접근 확인 아래와 같은 형태의 에러가 발생한다면 docker insecure 또는 harbor 설치 시 사용하였던 인증서를 각 Node VM에 신뢰하는 인증서로 추가
- EKS의 경우 VM에 ssh 하여 편집하고 AMI로 해당 이미지를 저장하여 Launch templates과 Auto Scaling groups를 수정해야 한다. 본 가이드에서는 harbor는 VM으로 빠져있기 때문에 /etc/hosts와 ca.crt를 EKS Worker Node VM에 등록 시킴

```
Error response from daemon: Get "https://xxx.xxx.leedh.cloud/v2/": x509: certificate is valid for  xxx.xxx.leedh.cloud
```

1) Insecure 추가 방안 

```
# /etc/docker/daemon.json 아래 실행 명령 추가
{
"insecure-registries":["xxx.xxx.leedh.cloud"]
}

$ docekr restart
```

2) CA 추가 방안 (Harbor 설치 시 생성 된 CA 파일을 VM의 신뢰하는 기관으로 추가)

```
# ubuntu 기준 /usr/local/share/ca-certificates 파일에 harbor ca 파일 생성
-rw-r--r-- 1 root root 2037 Nov  1 06:27 ca.crt
-rw-r--r-- 1 root root 2074 Oct 28 06:02 xxx.xxx.xxx.crt

$ sudo update-ca-certificates
```

## 1. Jenkins  Pipeline 설정

### 1.1. Jenkins 용 Private Registry Harbor 인증 설정 (Docker가 로그인 되어 있는 상태)
- Kubenetes에서 배포 할 Private Registry Harbor의 Image를 Pull 할 수 있도록 인증 정보를 생성

```
# default namespace에 배포 할 경우
$ kubectl create secret generic regcred \
--from-file=.dockerconfigjson=/home/leedh/.docker/config.json \
--type=kubernetes.io/dockerconfigjson
```


### 1.2. Jenkins Credential 생성

- Jenkins UI에서 [Jenkins 관리] -> [Managed Credentials] 버튼을 클릭
- Jenkins와 Source Code 저장 소 간 연동을 위한 Credentials을 생성 (API Token, User ID, User Password)
	- Sample에서는 Pipeline에서 자동으로 git clone을 하게 끔하기 위하여 User ID, User Password를 저장하였지만 기본 checkout pipeline을 사용하지 않고 API Token 1개로 사용도 가능 할 것으로 예상 됨


### 1.3. Jenkins Pipeline 설정

- Jenkins UI에서의 Pipeline 주요 설정 (Gitlab 연동 부분)

![jenkins-pipeline-1][jenkins-pipeline-1]

[jenkins-pipeline-1]:./images/jenkins-pipeline-1.PNG

### 1.4. Jenkinsfile 생성

- 대상의 git에서 실제 Jenkins Pipleline을 수행 할 Jenkins Script File을 생성한다.
- Stage 단계
	- Default Git Source Code Check Out
	- Maven Source Code Build
	- Docker Image Build
	- Docker Private Repo Push
	- Local Docker Image Delete
	- Deploy (Git Push -> ArgoCD Trigger)

```
pipeline {
    environment {
        GIT_SSL_NO_VERIFY = 0
        REGISTRY = "harbor.xxx.leedh.cloud"
        IMAGENAME = "cicd/test-app"
        GITLAB_API_TOKEN = credentials('GITLAB_API_TOKEN')
    }
  agent {
    kubernetes {
      label 'my-test-app-cicd'
      yamlFile 'cicd-template.yaml'
    }
  }
    stages {
       stage('Maven Source Code Build') {
          steps {
            container('maven') {
              echo "Check Maven"
              sh 'mvn -version'
              echo "Start Maven Build"
              sh 'mvn clean install'
              sh 'ls -al ./target'
            }
          }
        }
        stage('Build Docker Image') {
          steps {
            container('docker') {
              sh 'docker build -t $REGISTRY/$IMAGENAME:$BUILD_NUMBER .'
              sh 'docker images | grep $IMAGENAME'
            }
          }
        }
        stage('Push Docker Image Harbor') {
          steps {
            container('docker') {
              sh 'echo $HARBOR_PASSWORD | docker login -u$HARBOR_ID --password-stdin $REGISTRY'
              sh 'docker push $REGISTRY/$IMAGENAME:$BUILD_NUMBER'
            }
          }
        }
        stage('Local Docker Image Delete') {
          steps {
            container('docker') {
              sh 'IMAGE=$(docker images | grep $IMAGENAME | grep $BUILD_NUMBER)'
              sh """
                  docker images | grep $IMAGENAME | grep $BUILD_NUMBER | awk \'{print \$3}\' | xargs docker rmi -f
                 """
            }
          }
        }
        stage('Deploy') {
          steps {
            container('deploy') {
              sh 'export GIT_SSL_NO_VERIFY=0'
              sh 'git pull origin main'
              sh 'echo $GITLAB_API_TOKEN'
              sh 'git config --global user.email "leedh@test.com"'
              sh 'git checkout main'
              sh 'cd manifest/dev && kustomize edit set image harbor.xxx.leedh.cloud/cicd/test-app:$BUILD_NUMBER'
              sh 'git add .'
              sh 'git commit -a -m "updated test"'
              sh 'git push https://$GITLAB_API_TOKEN:$GITLAB_API_TOKEN@gitlab.xxx.leedh.cloud/root/my-test.git'
            }
          }
        }
    }
}
```


### 1.4. Jenkins Agent 설정
- 각 단계 별 실행 할 명령어가 들어가 있는 Agent 정의한다. 해당 Jenkins Script에서 사용한 명령은 maven, docker, kustomize 관련 cli가 들어가 있는 Docker File을 사용하였으며, Harbor에 Login 하기 위하여 Jenkins Name Space에 Harbor 정보를 Secret으로 설정 하였음

```
apiVersion: v1
kind: Pod
metadata:
  app: my-test-cicd
spec:
  volumes:
  - name: docker-sock
    hostPath:
      path: "/var/run/docker.sock"
  containers:
  - name: maven
    image: maven:alpine
    command:
    - cat
    tty: true
  - name: docker
    image: docker
    securityContext:
      privileged: true
      runAsUser: 0
    env:
    - name: HARBOR_ID
      valueFrom:
        secretKeyRef:
          name: harbor-login
          key: harbor-id
    - name: HARBOR_PASSWORD
      valueFrom:
        secretKeyRef:
          name: harbor-login
          key: harbor-password
    command:
    - cat
    tty: true
    volumeMounts:
      - mountPath: /var/run/docker.sock
        name: docker-sock
        readOnly: false

  - name: deploy
    image: cloudowski/drone-kustomize
    command:
    - cat
    tty: true
```

## 2. Agrocd 설정

- kustomize를 사용하기 위하여 아래 Tree 구조를 이용

```
├── base
│   ├── deployment-bluegreen.yaml
│   ├── deployment.yaml
│   ├── kustomization.yaml
│   ├── service-bluegreen.yaml
│   └── service.yaml
├── manifest
│   ├── dev
│   │   ├── deployment-bluegreen.yaml
│   │   ├── deployment-patch.yaml
│   │   ├── kustomization.yaml
│   │   ├── service-bluegreen.yaml
│   │   └── service-patch.yaml
│   └── prod
│       ├── deployment-patch.yaml
│       ├── kustomization.yaml
│       └── service-patch.yaml

```

- kustomize를 통하여 manifest yaml이 정상적으로 만들어 지는지 확인

```
$ kustomize build manifest/dev/
apiVersion: v1
kind: Service
metadata:
  labels:
    env: dev
  name: rollout-bluegreen-old
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: leedh-test-app
  type: NodePort
---
apiVersion: v1
kind: Service
metadata:
  labels:
    env: dev
  name: rollout-bluegreen-pre
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: leedh-test-app
  type: NodePort
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  labels:
    app: leedh-test-app
    env: dev
  name: leedh-test-deployment
spec:
  replicas: 3
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: leedh-test-app
  strategy:
    blueGreen:
      activeService: rollout-bluegreen-old
      autoPromotionEnabled: false
      previewService: rollout-bluegreen-pre
  template:
    metadata:
      labels:
        app: leedh-test-app
    spec:
      containers:
      - image: harbor.eks.leedh.cloud/cicd/test-app:93
        imagePullSecrets:
        - name: regcred
        name: leedh-test-app
        ports:
        - containerPort: 8080
```


- ArgoCD UI Application 주요 설정

![jenkins-pipeline-2][jenkins-pipeline-2]

[jenkins-pipeline-2]:./images/jenkins-pipeline-2.PNG


## 3. Jenkins Pileline 실행

- Jenkins Pileline 실행 화면

![jenkins-pipeline-3][jenkins-pipeline-3]

[jenkins-pipeline-3]:./images/jenkins-pipeline-3.PNG


## 4. Agrocd 실행

- Argocd 실행 화면

![jenkins-pipeline-4][jenkins-pipeline-4]

[jenkins-pipeline-4]:./images/jenkins-pipeline-4.PNG




