# Docker CE 설치 가이드

- 본 가이드는 Docker Offline 형태로 Package Download하여 dpkg install 방안과, Online Install 
- 외부 인터넷 환경이 되는 PC에서 선행 작업이 필요합니다.

## 1. Docker CE Offline Install

- 외부 통신이 되는 VM에서 선행 작업 합니다.
- apt 패키지 관리자를 통하여 Docker CE 관련 deb 파일을 download 하기 전 기존 package 들을 backup 합니다.

```
$ cd /var/cache/apt

# 기존 package 관리 폴더 backup
$ tar cvf archives-old.tar  archives

# 기존 package 관리 폴더 삭제
$ rm -rf archives
```


- apt 패키지 관리자를 통하여 Docker CE 관련 deb 파일을 download

```
$ sudo apt-get update

$ sudo apt-get install -y --download-only \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
	
$ sudo add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) \
stable"

$ sudo apt-get update
$ sudo apt-get install -y --download-only docker-ce docker-ce-cli containerd.io
```

- 위 결과 물을 바탕으로 Download 된 Package를 기반으로 tar로 묶어 Docker CE 설치 대상의 Offline VM으로 이동 시킵니다.

```
$ tar cvf docker-ce-deb.tar archives
$ scp docker-ce-deb.tar ubuntu@xxx.xxx.xxx.xx:~/.
```

- Offline VM으로 ssh 이동하여 tar 해제 후 모든 deb Package를 설치합니다.

```
$ tar xvf docker-ce-deb.tar 
$ cd archives
$ ls -al
root@ubuntu:/var/cache/apt/archives# ls -al
total 103268
drwxr-xr-x 3 root root    12288 Apr  9 06:52 .
drwxr-xr-x 3 root root     4096 Apr  9 06:52 ..
-rw-r--r-- 1 root root     1692 Mar 25 14:39 apt-transport-https_1.6.13_all.deb
-rw-r--r-- 1 root root 28256502 Apr  8 14:50 containerd.io_1.4.4-1_amd64.deb
-rw-r--r-- 1 root root   316136 Feb 15 10:40 dirmngr_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root 24812838 Apr  1 12:17 docker-ce_5%3a20.10.5~3-0~ubuntu-bionic_amd64.deb
-rw-r--r-- 1 root root 41403406 Apr  1 12:17 docker-ce-cli_5%3a20.10.5~3-0~ubuntu-bionic_amd64.deb
-rw-r--r-- 1 root root  8950664 Apr  1 12:17 docker-ce-rootless-extras_5%3a20.10.5~3-0~ubuntu-bionic_amd64.deb
-rw-r--r-- 1 root root   249164 Feb 15 10:40 gnupg_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root     4864 Feb 15 10:40 gnupg-agent_2.2.4-1ubuntu1.4_all.deb
-rw-r--r-- 1 root root    49828 Feb 15 10:40 gnupg-l10n_2.2.4-1ubuntu1.4_all.deb
-rw-r--r-- 1 root root   127576 Feb 15 10:40 gnupg-utils_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root   467352 Feb 15 10:40 gpg_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root   227244 Feb 15 10:40 gpg-agent_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root   123304 Feb 15 10:40 gpgconf_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root   214864 Feb 15 10:40 gpgsm_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root   198016 Feb 15 10:40 gpgv_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root    91824 Feb 15 10:40 gpg-wks-client_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root    84984 Feb 15 10:40 gpg-wks-server_2.2.4-1ubuntu1.4_amd64.deb
-rw-r--r-- 1 root root    38760 Nov  2  2016 libltdl7_2.4.6-2_amd64.deb
-rw-r----- 1 root root        0 Apr  9 06:13 lock
drwx------ 2 _apt root     4096 Apr  9 06:35 partial
-rw-r--r-- 1 root root    57448 Dec 28  2017 pigz_2.4-1_amd64.deb

$ dpkg -i *.deb

```

- Docker 설치 버전 확인

```
$ docker --version
Docker version 20.10.5, build 55c4c88
```


## 2. Docker CE Online Install

- 외부 통신이 가능한 VM에 Docker CE를 설치 할 경우 별다른 옵션 없이 apt 패키지 관리자로만 설치가 가능합니다.

```
$ sudo apt-get update

$ sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -


$ sudo add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) \
stable"

$ sudo apt-get update

$ sudo apt-get install docker-ce docker-ce-cli containerd.io

```

- 특정 버전 설치

```
$ apt-cache madison docker-ce 으로 버전 확인 후 해당 버전을 아래쪽에 입력
docker-ce | 5:20.10.5~3-0~ubuntu-bionic | https://download.docker.com/linux/ubuntu bionic/stable amd64 Packages
 docker-ce | 5:20.10.4~3-0~ubuntu-bionic | https://download.docker.com/linux/ubuntu bionic/stable amd64 Packages
....  생략

$ sudo apt-get install docker-ce=5:20.10.5~3-0~ubuntu-bionic docker-ce-cli=5:20.10.5~3-0~ubuntu-bionic containerd.io
```

- Docker 설치 버전 확인

```
$ docker --version
Docker version 20.10.5, build 55c4c88
```


## 3. Docker Image 설치 확인

- 사전 준비 사항 docker image file

```
$ service docker start

$ docker images
REPOSITORY           TAG       IMAGE ID       CREATED       SIZE

$ ls -al
ls -al
total 128920
drwxr-xr-x 2 root   root        4096 Apr  9 07:46 .
drwxr-xr-x 5 ubuntu ubuntu      4096 Apr  9 07:46 ..
-rw------- 1 root   root   132004352 Apr  9 07:46 leedh.image


$ docker load < leedh.image
f1b5933fe4b5: Loading layer [==================================================>]  5.796MB/5.796MB
9b9b7f3d56a0: Loading layer [==================================================>]  3.584kB/3.584kB
ceaf9e1ebef5: Loading layer [==================================================>]  100.2MB/100.2MB
58da1ffa4adb: Loading layer [==================================================>]  12.29kB/12.29kB
60565a6e82db: Loading layer [==================================================>]  25.94MB/25.94MB
Loaded image: leedh/rolling-test:2.0

$ docker images
REPOSITORY           TAG       IMAGE ID       CREATED       SIZE
leedh/rolling-test   2.0       09d2dbc0b4b3   7 weeks ago   131MB

$ docker run leedh/rolling-test:2.0

  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::        (v2.2.1.RELEASE)

2021-04-09 08:51:35.555  INFO 1 --- [           main] com.mzc.boot.SimpleBootApplication       : Starting SimpleBootApplication v0.0.1-SNAPSHOT on f6e992e194ff with PID 1 (/app.jar started by spring in /)
2021-04-09 08:51:35.583  INFO 1 --- [           main] com.mzc.boot.SimpleBootApplication       : No active profile set, falling back to default profiles: default
2021-04-09 08:51:49.640  INFO 1 --- [           main] faultConfiguringBeanFactoryPostProcessor : No bean named 'errorChannel' has been explicitly defined. Therefore, a default PublishSubscribeChannel will be created.
2021-04-09 08:51:49.716  INFO 1 --- [           main] faultConfiguringBeanFactoryPostProcessor : No bean named 'taskScheduler' has been explicitly defined. Therefore, a default ThreadPoolTaskScheduler will be created.
2021-04-09 08:51:49.840  INFO 1 --- [           main] faultConfiguringBeanFactoryPostProcessor : No bean named 'integrationHeaderChannelRegistry' has been explicitly defined. Therefore, a default DefaultHeaderChannelRegistry will be created.
```
