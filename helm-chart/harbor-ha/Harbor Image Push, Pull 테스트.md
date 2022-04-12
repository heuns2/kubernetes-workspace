# Harbor Image Push, Pull 테스트

## 1. Harbor Image Push, Pull 테스트 

### 1.1. Docker Install

```
$ sudo yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo
$ sudo yum install docker-ce docker-ce-cli containerd.io
```

### 1.2. Docker Login
- 신뢰하지 않는 인증서를 사용 할 경우 /etc/docker/daemon.json을 작성하거나 인증서를 OS에 추가 해야 합니다.

```
$ docker login harbor.xxx.xxx
Username: admin
Password:
```

### 1.2. Docker Pull / Push

- Sample Docker Image를 Harbor에 Push

```
# Docker Imagee Pull
$ docker pull hello-world
Using default tag: latest
docker imageslatest: Pulling from library/hello-world
2db29710123e: Pull complete
Digest: sha256:bfea6278a0a267fad2634554f4f0c6f31981eea41c553fdf5a83e95a41d40c38
Status: Downloaded newer image for hello-world:latest
docker.io/library/hello-world:latest

# Docker Image 확인
$ docker images
REPOSITORY    TAG       IMAGE ID       CREATED        SIZE
hello-world   latest    feb5d9fea6a5   6 months ago   13.3kB

# Docker Tag 지정
$ docker tag hello-world:latest harbor.xxx.xxx/xxx/hello-world:1.0

# Docker Push
docker push harbor.xxx.xxx/xxx/hello-world:1.0
```

![docker-push-test-1][docker-push-test-1]

[docker-push-test-1]:./images/docker-push-test-1.PNG


### 1.3.K8S 배포

- Docker Registry Harbor 인증 용 Secret 생성

```
$ kubectl create secret docker-registry regcred --docker-server=https://harbor.xxx.xxx --docker-username=admin --docker-password=xxxxx --docker-email=test.com
```

- Sample Pod 배포

```
$ cat sample-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: private-reg
spec:
  containers:
  - name: private-reg-container
    image: harbor.xxx.xxx/xxx/hello-world:1.0
  imagePullSecrets:
  - name: regcred

$ kubectl apply -f sample-pod.yaml

```

- Sample Pod Image Pulling 확인

```
$ kubectl describe pods private-reg  | grep -i pul
  Normal   Pulling    5m38s (x5 over 6m58s)  kubelet            Pulling image "harbor.xxx.xxx/xxx/hello-world:1.0"
  Normal   Pulled     5m37s                  kubelet            Successfully pulled image "harbor.xxx.xxx/xxx/hello-world:1.0" in 185.437104ms
```
