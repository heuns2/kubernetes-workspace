# Private Docker Registry Install
- Rancher에서 관리 대상의 Offline Kubespray 설치를 위한 Private Docker Registry 설치

## 1. Docker Install Centos

### 1.1. 외부 통신이 되는 환경에서 작업

- 외부 망 통신이 되는 환경에서 Docker Centos Dependency 다운로드

```
# 기존 Docker 삭제
$ sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

# yum-utils 설치(Optional)
$ sudo yum install -y yum-utils

# Docker Repo 등록
$ sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

# Docker Centos RPM 파일 일괄 다운로드 & 압축
$ mkdir ~/docker
$ cd ~/docker
$ yumdownloader --resolve docker-ce-20.10.13 # 20.10.13 특정 버전으로 다운로드 할 경우 명시
$ tar cvzf ~/docker.tar.gz *

# Offline Registry 설치 대상 VM으로 SCP 이동
```

### 1.2. Offline Private Registry 실행 환경에서 작업

- Offline Registry 설치 대상 VM 에서 실행

```
# Docker RPM 설치
$ mkdir docker
$ tar xvf docker.tar.gz -C ~/docker
$ cd docker
$ sudo rpm -ivh --replacefiles --replacepkgs *.rpm

# 일반 User 등록
$ sudo usermod -aG docker $USER

# Docker Service 등록 & 시작
$ sudo systemctl enable docker.service
$ sudo systemctl start docker.service
```


## 2. Image Registry 실행

### 2.1. 외부 통신이 되는 환경에서 작업

- 외부 통신이 되는 VM에서 Registry Image를 압축 파일로 다운로드

```
$ docker pull registry
$ docker images
$ docker save -o registrydocker save -o registry.tgz registry

# registry.tgz 파일을 Offline Registry 설치 대상 VM으로 SCP 이동
```

### 2.2. Offline Private Registry 실행 환경에서 작업

- docker를 통해 registry 실행

```
# Registry 실행
$ docker run -dit --name docker-registry --restart=always -p 5000:5000 -v /root/data:/var/lib/registry/docker/registry/v2 registry

# 확인
$ curl localhost:5000/v2/_catalog
{"repositories":[]}
```
