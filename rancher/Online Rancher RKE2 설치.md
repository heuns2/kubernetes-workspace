# 1. Online Rancher RKE2 설치
- 문서 작성일 2022-03-22을 기준으로 v1.22.7+rke2r1 REK2 설치 가이드이며, Online 설치를 기준으로 작성
- Rancher RKE2는 Rancher Kubenetes Engine과 K3(Mircro)의 장점을 결합 한 솔루션
- RKE와는 다르게 ControlPlane 영역을 Docker를 Runtime으로 사용하지 않고 Kubelet에서 관리하는 Runtime Config로 실행
- 주의 사항으로는 RKE2 버전을 최신버전으로 올릴 경우 Rancher UI 배포가 되지 않을 수 있음

## Requirements

- Operating Systems Requirements

| ID| Version|
|--|--|
|Ubuntu |18.04 (amd64)|
|Ubuntu |16.04 (amd64)|
|CentOS/RHEL|7.8(amd64)|
|CentOS/RHEL|8.2 (amd64)|
|SLES| 15 SP2 (amd64)|

- Hardware Requirements
	-   RAM: 4GB Minimum (we recommend at least 8GB)
	-   CPU: 2 Minimum (we recommend at least 4CPU)

- Disk Recommend 
	- RKE2의 성능은 데이터베이스의 성능에 따라 달라지며, RKE2는 etcd를 내장하여 실행하고 데이터 dir을 디스크에 저장하므로 최적의 성능을 보장하기 위해 가능한 SSD를 사용하는 것을 권장

 - Networking Check
	 - NetworkManager가 활성화 되어 있는 경우 CNI를 무시 하도록 설정 필요
	 - Wicked가 설치 되어 있는 경우 ipv4.conf.all.forwarding 설정 변경 필요

- Node Prerequisites
	- 각 Server Node 별 권한 필요

- System Recommended
	- systemctl disable firewalld --now
	- systemctl disable nm-cloud-setup.service nm-cloud-setup.timer
    - reboot


## 1. Rancher Server Node Install

- 모든 Node에 특정 버전 RKE Package Install

```
$ curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=v1.22.7+rke2r1 sh -
```


- Rancher Server 설치 대상 모든 Node 환경에 접속하여 Swap 비활성화, Network 브릿시 설정

```
$ sudo swapoff -a
$ sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

$ cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

$ cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
$ sudo sysctl --system
```


### 1.1. 첫번째 Node에서 작업

-  Config File 작성 및 설정

```
# Config 파일 작성
$ mkdir -p /etc/rancher/rke2
cat << EOF >  /etc/rancher/rke2/config.yaml
write-kubeconfig-mode: "0644"
tls-san:
  - "rancher.prd.leedh.xyz"
  - "10.250.223.79"
  - "10.250.210.24"
  - "10.250.211.95"
token: shared-secret-token
profile: "cis-1.6"
selinux: true
cni: calico
EOF

# selinux 설정
$ sudo cp -f /usr/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
$ sysctl -p /etc/sysctl.d/60-rke2-cis.conf
$ useradd -r -c "etcd user" -s /sbin/nologin -M etcd
```

- RKE2 Cluster 실행

```
# 서비스 등록
$ systemctl enable rke2-server.service

# 서비스 시작
# systemctl start rke2-server.service

# 시스템 동작 확인
$ systemctl status rke2-server.service
● rke2-server.service - Rancher Kubernetes Engine v2 (server)
   Loaded: loaded (/usr/lib/systemd/system/rke2-server.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2022-03-22 08:55:25 UTC; 55s ago
     Docs: https://github.com/rancher/rke2#readme
  Process: 9429 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
  Process: 9424 ExecStartPre=/sbin/modprobe br_netfilter (code=exited, status=0/SUCCESS)
  Process: 9420 ExecStartPre=/bin/sh -xc ! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service (code=exited, status=0/SUCCESS)
 Main PID: 9433 (rke2)

# Node 확인
$ /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes
NAME                                               STATUS   ROLES                       AGE     VERSION
ip-10-250-223-79.ap-northeast-1.compute.internal   Ready    control-plane,etcd,master   2m11s   v1.23.4+rke2r1

# Pod 확인
$ /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods -A
NAMESPACE         NAME                                                                        READY   STATUS      RESTARTS   AGE
calico-system     calico-kube-controllers-7f9889b949-bgbt5                                    1/1     Running     0          105s
calico-system     calico-node-hh6pc                                                           1/1     Running     0          105s
calico-system     calico-typha-849d67f948-p6phh                                               1/1     Running     0          105s
kube-system       cloud-controller-manager-ip-10-250-223-79.ap-northeast-1.compute.internal   1/1     Running     0          2m56s
kube-system       etcd-ip-10-250-223-79.ap-northeast-1.compute.internal                       1/1     Running     0          2m35s
kube-system       helm-install-rke2-calico-crd-wbhqz                                          0/1     Completed   0          2m38s
kube-system       helm-install-rke2-calico-cvc7d                                              0/1     Completed   2          2m38s
kube-system       helm-install-rke2-coredns-dxl56                                             0/1     Completed   0          2m38s
kube-system       helm-install-rke2-ingress-nginx-tm9md                                       0/1     Completed   0          2m38s
kube-system       helm-install-rke2-metrics-server-4rdzn                                      0/1     Completed   0          2m38s
kube-system       kube-apiserver-ip-10-250-223-79.ap-northeast-1.compute.internal             1/1     Running     0          2m29s
kube-system       kube-controller-manager-ip-10-250-223-79.ap-northeast-1.compute.internal    1/1     Running     0          2m59s
kube-system       kube-proxy-ip-10-250-223-79.ap-northeast-1.compute.internal                 1/1     Running     0          2m36s
kube-system       kube-scheduler-ip-10-250-223-79.ap-northeast-1.compute.internal             1/1     Running     0          2m59s
kube-system       rke2-coredns-rke2-coredns-869b5d56d4-jrfbk                                  1/1     Running     0          2m14s
kube-system       rke2-coredns-rke2-coredns-autoscaler-5b947fbb77-r55ln                       1/1     Running     0          2m14s
kube-system       rke2-ingress-nginx-controller-lbtnq                                         1/1     Running     0          48s
kube-system       rke2-metrics-server-6564db4569-25g68                                        1/1     Running     0          64s
tigera-operator   tigera-operator-6df8b7694c-vk2zj                                            1/1     Running     0          117s
```

### 1.2. HA 구성을 위한 나머지 Node에서 작업

- L4를 통하여 FQDN 9345 Rancher Server 등록 후 실행
-  Config File 작성 및 설정

```
# Config 파일 작성 
mkdir -p /etc/rancher/rke2
cat << EOF >  /etc/rancher/rke2/config.yaml
server:  https://rancher.prd.leedh.xyz # Control Plane FQDN이 필요 할 수 있음 10.250.223.79:9345
token:  K10206839830eeb931f3c99562e41d4603e581feb767c6ea8e248a214c693092c7b::server:shared-secret-token # Token 값은 첫번 째 Node의 /var/lib/rancher/rke2/server/node-token 디렉토리 참조
write-kubeconfig-mode: "0644"
tls-san:
  - "rancher.prd.leedh.xyz"
  - "10.250.223.79"
  - "10.250.210.24"
  - "10.250.211.95"
token: shared-secret-token
profile: "cis-1.6"
selinux: true
cni: calico
EOF

# selinux 설정
$ sudo cp -f /usr/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
$ sysctl -p /etc/sysctl.d/60-rke2-cis.conf
$ useradd -r -c "etcd user" -s /sbin/nologin -M etcd
```



- RKE2 Cluster 실행

```
# 서비스 등록
$ systemctl enable rke2-server.service

# 서비스 시작
$ systemctl restart rke2-server.service

# 시스템 동작 확인
$ systemctl status rke2-server.service
● rke2-server.service - Rancher Kubernetes Engine v2 (server)
   Loaded: loaded (/usr/lib/systemd/system/rke2-server.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2022-03-22 09:29:20 UTC; 2min 17s ago
     Docs: https://github.com/rancher/rke2#readme
  Process: 18599 ExecStopPost=/bin/sh -c systemd-cgls /system.slice/%n | grep -Eo '[0-9]+ (containerd|kubelet)' | awk '{print $1}' | xargs -r kill (code=exited, status=0/SUCCESS)
  Process: 18617 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
  Process: 18614 ExecStartPre=/sbin/modprobe br_netfilter (code=exited, status=0/SUCCESS)
  Process: 18611 ExecStartPre=/bin/sh -xc ! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service (code=exited, status=0/SUCCESS)
 Main PID: 18620 (rke2)
    Tasks: 133
   Memory: 2.0G
   CGroup: /system.slice/rke2-server.service



# Node 확인
$ /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes
NAME                                               STATUS   ROLES                       AGE    VERSION
ip-10-250-210-24.ap-northeast-1.compute.internal   Ready    control-plane,etcd,master   115s   v1.23.4+rke2r1
ip-10-250-211-95.ap-northeast-1.compute.internal   Ready    control-plane,etcd,master   99s    v1.23.4+rke2r1
ip-10-250-223-79.ap-northeast-1.compute.internal   Ready    control-plane,etcd,master   35m    v1.23.4+rke2r1

# Pod 확인
$ /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods -A
NAMESPACE         NAME                                                                        READY   STATUS      RESTARTS   AGE
calico-system     calico-kube-controllers-7f9889b949-bgbt5                                    1/1     Running     0          35m
calico-system     calico-node-bbskd                                                           1/1     Running     0          2m23s
calico-system     calico-node-hh6pc                                                           1/1     Running     0          35m
calico-system     calico-node-nswnr                                                           1/1     Running     0          2m39s
calico-system     calico-typha-849d67f948-p6phh                                               1/1     Running     0          35m
calico-system     calico-typha-849d67f948-wjstf                                               1/1     Running     0          2m18s
kube-system       cloud-controller-manager-ip-10-250-210-24.ap-northeast-1.compute.internal   1/1     Running     0          111s
kube-system       cloud-controller-manager-ip-10-250-211-95.ap-northeast-1.compute.internal   1/1     Running     0          100s
kube-system       cloud-controller-manager-ip-10-250-223-79.ap-northeast-1.compute.internal   1/1     Running     0          36m
kube-system       etcd-ip-10-250-210-24.ap-northeast-1.compute.internal                       1/1     Running     0          111s
kube-system       etcd-ip-10-250-211-95.ap-northeast-1.compute.internal                       1/1     Running     0          2m4s
kube-system       etcd-ip-10-250-223-79.ap-northeast-1.compute.internal                       1/1     Running     0          36m
kube-system       helm-install-rke2-calico-crd-wbhqz                                          0/1     Completed   0          36m
kube-system       helm-install-rke2-calico-cvc7d                                              0/1     Completed   2          36m
kube-system       helm-install-rke2-coredns-dxl56                                             0/1     Completed   0          36m
kube-system       helm-install-rke2-ingress-nginx-tm9md                                       0/1     Completed   0          36m
kube-system       helm-install-rke2-metrics-server-4rdzn                                      0/1     Completed   0          36m
kube-system       kube-apiserver-ip-10-250-210-24.ap-northeast-1.compute.internal             1/1     Running     0          2m2s
kube-system       kube-apiserver-ip-10-250-211-95.ap-northeast-1.compute.internal             1/1     Running     0          112s
kube-system       kube-apiserver-ip-10-250-223-79.ap-northeast-1.compute.internal             1/1     Running     0          36m
kube-system       kube-controller-manager-ip-10-250-210-24.ap-northeast-1.compute.internal    1/1     Running     0          111s
kube-system       kube-controller-manager-ip-10-250-211-95.ap-northeast-1.compute.internal    1/1     Running     0          98s
kube-system       kube-controller-manager-ip-10-250-223-79.ap-northeast-1.compute.internal    1/1     Running     0          36m
kube-system       kube-proxy-ip-10-250-210-24.ap-northeast-1.compute.internal                 1/1     Running     0          112s
kube-system       kube-proxy-ip-10-250-211-95.ap-northeast-1.compute.internal                 1/1     Running     0          93s
kube-system       kube-proxy-ip-10-250-223-79.ap-northeast-1.compute.internal                 1/1     Running     0          36m
kube-system       kube-scheduler-ip-10-250-210-24.ap-northeast-1.compute.internal             1/1     Running     0          2m1s
kube-system       kube-scheduler-ip-10-250-211-95.ap-northeast-1.compute.internal             1/1     Running     0          104s
kube-system       kube-scheduler-ip-10-250-223-79.ap-northeast-1.compute.internal             1/1     Running     0          36m
kube-system       rke2-coredns-rke2-coredns-869b5d56d4-jrfbk                                  1/1     Running     0          35m
kube-system       rke2-coredns-rke2-coredns-869b5d56d4-rpnvl                                  1/1     Running     0          2m34s
kube-system       rke2-coredns-rke2-coredns-autoscaler-5b947fbb77-r55ln                       1/1     Running     0          35m
kube-system       rke2-ingress-nginx-controller-h8l9j                                         1/1     Running     0          97s
kube-system       rke2-ingress-nginx-controller-lbtnq                                         1/1     Running     0          34m
kube-system       rke2-ingress-nginx-controller-s7l5x                                         1/1     Running     0          100s
kube-system       rke2-metrics-server-6564db4569-25g68                                        1/1     Running     0          34m
tigera-operator   tigera-operator-6df8b7694c-vk2zj                                            1/1     Running     0          35m
```
