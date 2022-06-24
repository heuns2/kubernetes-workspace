# Offline Package Download & Registry Push 방안
  
1. Docker Registry Insecure 등록

```
$ cat /etc/docker/daemon.json  
{ "insecure-registries":["xxx.xxx.xxx.xxx:5000"] }
```
  
3. Docker 원격지 로그인

```
$ docker login http://xxx.xxx.xxx.xxx:5000 
Username: admin  
Password:  
WARNING! Your password will be stored unencrypted in /home/leedh/.docker/config.json.  
Configure a credential helper to remove this warning. See  
[https://docs.docker.com/engine/reference/commandline/login/#credentials-store](https://docs.docker.com/engine/reference/commandline/login/#credentials-store)  
  
Login Succeeded
```
  
3. offline 스크립트가 존재하는 디렉토리 이동

```
$ cd kubespray-2.15.0/contrib/offline
```
  

4. ./docker-daemon.json 파일 수정

```
$ cat docker-daemon.json  
{ "insecure-registries":["xxx.xxx.xxx.xxx:5000"] }
```
  

5. ./manage-offline-container-images.sh 스크립트 파일 수정
- LOCALHOST_NAME을 원격지 Registry IP로 변경

![ks-1][ks-1]
[ks-1]:./images/ks-1.png

6. 스크립트 실행

```
$ ./manage-offline-container-images.sh register  
./container-images/  
./container-images/nvcr.io-nvidia-k8s-dcgm-exporter-2.1.4-2.2.0-ubuntu20.04.tar  
./container-images/quay.io-calico-cni-v3.16.5.tar  
./container-images/quay.io-kubernetes_incubator-node-feature-discovery-v0.6.0.tar  
./container-images/k8s.gcr.io-kube-apiserver-v1.19.7.tar  
./container-images/nvcr.io-nvidia-k8s-device-plugin-v0.8.1.tar  
./container-images/k8s.gcr.io-dns-k8s-dns-node-cache-1.16.0.tar  
./container-images/nvcr.io-nvidia-k8s-cuda-sample-vectoradd-cuda10.2.tar  
./container-images/quay.io-calico-kube-controllers-v3.16.5.tar  
./container-images/k8s.gcr.io-pause-3.3.tar  
./container-images/nvcr.io-nvidia-driver-470.103.01-ubuntu20.04.tar  
./container-images/quay.io-shivamerla-gpu-operator-1.6.0.tar  
./container-images/nvcr.io-nvidia-gpu-feature-discovery-v0.4.0.tar  
./container-images/quay.io-calico-node-v3.16.5.tar  
./container-images/nvcr.io-nvidia-cuda@sha256-ed723a1339cddd75eb9f2be2f3476edf497a1b189c10c9bf9eb8da4a16a51a59.tar  
./container-images/nvcr.io-nvidia-k8s-container-toolkit-1.4.5-ubuntu18.04.tar  
./container-images/k8s.gcr.io-kube-scheduler-v1.19.7.tar  
./container-images/quay.io-coreos-etcd-v3.4.13.tar  
./container-images/docker.io-library-nginx-1.19.tar  
./container-images/registry-latest.tar  
./container-images/k8s.gcr.io-cpa-cluster-proportional-autoscaler-amd64-1.8.3.tar  
./container-images/container-images.txt  
./container-images/k8s.gcr.io-kube-proxy-v1.19.7.tar  
./container-images/k8s.gcr.io-coredns-1.7.0.tar  
./container-images/k8s.gcr.io-pause-3.2.tar  
./container-images/k8s.gcr.io-kube-controller-manager-v1.19.7.tar  
Loaded image: registry:latest  
337cae140000c530a2295f637d9543d6b9dcbd506caafebad2dee261da0cb944  
Loaded image: nginx:1.19  
The push refers to repository [[35.235.112.44:5000/library/nginx](http://35.235.112.44:5000/library/nginx)]  
f0f30197ccf9: Pushed  
eeb14ff930d4: Pushed  
c9732df61184: Pushed  
4b8db2d7f35a: Pushed  
431f409d4c5a: Pushed  
02c055ef67f5: Pushed  
1.19: digest: sha256:eba373a0620f68ffdc3f217041ad25ef084475b8feb35b992574cd83698e9e3c size: 1570  
225df95e717c: Loading layer [==================================================>] 336.4kB/336.4kB  
96d17b0b58a7: Loading layer [==================================================>] 45.02MB/45.02MB  
Loaded image:  [k8s.gcr.io/coredns:1.7.0](http://k8s.gcr.io/coredns:1.7.0)  
The push refers to repository [**[35.235.112.44:5000/coredns](http://35.235.112.44:5000/coredns)**]  
96d17b0b58a7: Preparing  
225df95e717c: Pushing [>  ] 2.56kB/212.7kB
```
  
7. 확인
![ks-2][ks-2]
[ks-1]:./images/ks-2.png

8. 스크립트 실행 중 아래 장애 발생 시 Registry를 Kill하여 재기동,

```
docker: Error response from daemon: Conflict. The container name "/registry" is already in use by container "  337cae140000e14e42db10b2634046903a4332c246e17e38561c3c7d632f83ab1ab". You have to remove (or rename) that container to be able to reuse that name.  
See 'docker run --help'.  

$ docker ps -a  
CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES  
337cae140000 registry:latest "/entrypoint.sh /etc…" 9 minutes ago Up 9 minutes 0.0.0.0:5000->5000/tcp, :::5000->5000/tcp registry  

 
$ docker rm 337cae140000

```
