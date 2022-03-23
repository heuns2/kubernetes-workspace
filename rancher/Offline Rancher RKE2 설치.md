# 1. Offline Rancher RKE2 설치
- 문서 작성일 2022-03-17을 기준으로 REK2 설치 가이드이며, Offline 설치를 기준으로 작성
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



## 1. Rancher Server Node Install (Offline)

### 1.1. RPM Packager Install & Rancher Image 설정
- 특이 사항으로는 설치 대상의 RKE2와 RPM Dependency 버전을 동일 하게 변경 필요
- Public 망 대역의 VM에서 Rancher Server 설치 용 RPM Dependency를 생성하여 Node에 scp

```
# RPM Repo 등록
$ cat << EOF > /etc/yum.repos.d/rancher-rke2-1-18-latest.repo  [rancher-rke2-common-latest]  name=Rancher RKE2 Common Latest  baseurl=https://rpm.rancher.io/rke2/latest/common/centos/7/noarch  enabled=1  gpgcheck=1  gpgkey=https://rpm.rancher.io/public.key  [rancher-rke2-1-18-latest]  name=Rancher RKE2 1.18 Latest  baseurl=https://rpm.rancher.io/rke2/latest/1.18/centos/7/x86_64  enabled=1  gpgcheck=1  gpgkey=https://rpm.rancher.io/public.key  EOF

# rancher server RPM Package Download
$ yumdownloader --resolve rke2-server

#다운로드 한 폴더를 압축 후 Server 설치 대상의 Node로 scp
$ tar cvf rancher-server.tar rancher-server/
$ scp -i ~/.ssh/tas.pem rancher-server.tar centos@10.250.218.59:~/
```

- Rancher Server 설치 대상 모든 Node 환경에 접속하여 Rpm Dependency Install

```
$ ssh -i ~/.ssh/tas.pem centos@10.250.218.xx

# rancher-server 압축 파일 해제 & 이동
$ tar xvf rancher-server.tar
$ cd rancher-server
$ sudo rpm -ivh --replacefiles --replacepkgs *.rpm
```

- Rancher Server용 Image을 다운로드 하여  모든 Node에 scp
	- Release Note: https://github.com/rancher/rke2/releases
	- 주의 사항은 rke2-images.linux-amd64.tar.gz -> tar.gz 반드시 해당 파일 그대로 이동 시켜야 함

```
$ curl -OLs https://github.com/rancher/rke2/releases/download/v1.23.4%2Brke2r2/rke2-images.linux-amd64.tar.gz
$ scp -i ~/.ssh/tas.pem rke2-images.linux-amd64.tar.gz centos@10.250.218.xx:~/
# 대상 서버에 접근
$ ssh -i ~/.ssh/tas.pem centos@10.250.218.xx

# 압축 파일을 /var/lib/rancher/rke2/agent/images로 이동
$ mv rke2-images.linux-amd64.tar.gz /var/lib/rancher/rke2/agent/images
... 생략
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


### 1.2. Rancher Server Node Start

- 첫 번째 Node에서 Config File을 생성하여 Rancher Server를 시작 & 확인

```
# Config 파일 작성
mkdir -p /etc/rancher/rke2
cat << EOF >  /etc/rancher/rke2/config.yaml
write-kubeconfig-mode: "0644"
tls-san:
  - "rancher.test.leedh"
  - "10.250.218.59"
  - "10.250.208.15"
  - "10.250.208.15"
token: my-shared-secret
profile: "cis-1.5"
selinux: true
EOF

# selinux 설정
$ sudo cp -f /usr/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
$ sysctl -p /etc/sysctl.d/60-rke2-cis.conf
$ useradd -r -c "etcd user" -s /sbin/nologin -M etcd


# RKE2 Server UP
$ systemctl enable rke2-server.service
$ systemctl start rke2-server.service
$ journalctl -u rke2-server -f

# RKE2 Server 확인
systemctl status rke2-server.service
● rke2-server.service - Rancher Kubernetes Engine v2 (server)
   Loaded: loaded (/usr/lib/systemd/system/rke2-server.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2022-03-18 00:25:10 UTC; 49s ago
     Docs: https://github.com/rancher/rke2#readme
  Process: 3116 ExecStartPre=/sbin/modprobe overlay (code=exited, status=0/SUCCESS)
  Process: 3113 ExecStartPre=/sbin/modprobe br_netfilter (code=exited, status=0/SUCCESS)
  Process: 3110 ExecStartPre=/bin/sh -xc ! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service (code=exited, status=0/SUCCESS)
 Main PID: 3119 (rke2)
    Tasks: 117
   Memory: 2.4G
   CGroup: /system.slice/rke2-server.service
           ├─3119 /usr/bin/rke2 server
           ├─3128 containerd -c /var/lib/rancher/rke2/agent/etc/containerd/config.toml -a /run/k3s/containerd/containerd.sock --state /run/k3s/containerd...
           ├─3163 kubelet --volume-plugin-dir=/var/lib/kubelet/volumeplugins --file-check-frequency=5s --sync-frequency=30s --address=0.0.0.0 --alsologto...
           ├─3267 /var/lib/rancher/rke2/data/v1.23.4-rke2r2-341f528638aa/bin/containerd-shim-runc-v2 -namespace k8s.io -id 94dd8bee835829dac032ebacb5e55a...
           ├─3345 /var/lib/rancher/rke2/data/v1.23.4-rke2r2-341f528638aa/bin/containerd-shim-runc-v2 -namespace k8s.io -id fe5d4fb149d3f5ac9bbb1e67268547...
           ├─3427 /var/lib/rancher/rke2/data/v1.23.4-rke2r2-341f528638aa/bin/containerd-shim-runc-v2 -namespace k8s.io -id 19d3308e2a474d999855321d9120e3...
           ├─3451 /var/lib/rancher/rke2/data/v1.23.4-rke2r2-341f528638aa/bin/containerd-shim-runc-v2 -namespace k8s.io -id 9f27b34745d4acb34bde1c549089f5...
           ├─3575 /var/lib/rancher/rke2/data/v1.23.4-rke2r2-341f528638aa/bin/containerd-shim-runc-v2 -namespace k8s.io -id 6a296dd5569b41483d7d52da44a39e...
           ├─3653 /var/lib/rancher/rke2/data/v1.23.4-rke2r2-341f528638aa/bin/containerd-shim-runc-v2 -namespace k8s.io -id 8220bd06ff37865bf779b6be02ea87...
           └─4316 /var/lib/rancher/rke2/data/v1.23.4-rke2r2-341f528638aa/bin/containerd-shim-runc-v2 -namespace k8s.io -id 10d368f7567bdf425cb860323f2d3d...

$ /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get nodes
NAME                                               STATUS   ROLES                       AGE   VERSION
ip-10-250-218-59.ap-northeast-1.compute.internal   Ready    control-plane,etcd,master   32m   v1.23.4+rke2r2

$ /var/lib/rancher/rke2/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods -A
NAMESPACE     NAME                                                                        READY   STATUS      RESTARTS        AGE
kube-system   cloud-controller-manager-ip-10-250-218-59.ap-northeast-1.compute.internal   1/1     Running     2 (5m46s ago)   32m
kube-system   etcd-ip-10-250-218-59.ap-northeast-1.compute.internal                       1/1     Running     1 (7m20s ago)   32m
kube-system   helm-install-rke2-canal-4h766                                               0/1     Completed   0               32m
kube-system   helm-install-rke2-coredns-kslgl                                             0/1     Completed   0               32m
kube-system   helm-install-rke2-ingress-nginx-tqtvf                                       1/1     Running     0               32m
kube-system   helm-install-rke2-metrics-server-c4gm7                                      1/1     Running     0               32m
kube-system   kube-apiserver-ip-10-250-218-59.ap-northeast-1.compute.internal             1/1     Running     1 (7m20s ago)   32m
kube-system   kube-controller-manager-ip-10-250-218-59.ap-northeast-1.compute.internal    1/1     Running     2 (5m37s ago)   32m
kube-system   kube-proxy-ip-10-250-218-59.ap-northeast-1.compute.internal                 1/1     Running     1 (7m20s ago)   32m
kube-system   kube-scheduler-ip-10-250-218-59.ap-northeast-1.compute.internal             1/1     Running     1 (7m20s ago)   32m
kube-system   rke2-canal-hw6hb                                                            2/2     Running     2 (7m20s ago)   32m
kube-system   rke2-coredns-rke2-coredns-869b5d56d4-v78sh                                  1/1     Running     1 (7m20s ago)   32m
kube-system   rke2-coredns-rke2-coredns-autoscaler-5b947fbb77-w7csq                       1/1     Running     0               32m
```

- HA 구성을 위한 2~3번 째 Node에서 Config File을 생성하여 Rancher Server를 시작 & 확인 (AWS 기준 약 5분 정도 소요)

```
# Config 파일 작성
mkdir -p /etc/rancher/rke2
cat << EOF >  /etc/rancher/rke2/config.yaml
write-kubeconfig-mode: "0644"
server:  https://10.250.218.59:9345 # Control Plane FQDN이 필요 할 수 있음
token:  K10a8536990ca1c5c0c800fba8df4d7bf7e3e61b34f269b6c138c99af771b774512::server:my-shared-secret # Token 값은 첫번 째 Node의 /var/lib/rancher/rke2/server/node-token 디렉토리 참조
tls-san:
  - "rancher.test.leedh"
  - "10.250.218.59"
  - "10.250.208.15"
  - "10.250.208.15"
profile: "cis-1.5"
selinux: true
EOF

# selinux 설정
$ sudo cp -f /usr/share/rke2/rke2-cis-sysctl.conf /etc/sysctl.d/60-rke2-cis.conf
$ sysctl -p /etc/sysctl.d/60-rke2-cis.conf
$ useradd -r -c "etcd user" -s /sbin/nologin -M etcd

# RKE2 Server UP
$ systemctl enable rke2-server.service
$ systemctl start rke2-server.service
$ journalctl -u rke2-server -f

# RKE2 Server 확인

# Node 들 형상 확인
$ kubectl get nodes
NAME                                                STATUS   ROLES                       AGE     VERSION
ip-10-250-208-15.ap-northeast-1.compute.internal    Ready    control-plane,etcd,master   2m18s   v1.23.4+rke2r2
ip-10-250-218-216.ap-northeast-1.compute.internal   Ready    control-plane,etcd,master   2m27s   v1.23.4+rke2r2
ip-10-250-218-59.ap-northeast-1.compute.internal    Ready    control-plane,etcd,master   14h     v1.23.4+rke2r2

# Pod 목록 확인
[root@ip-10-250-218-59 ~]# kubectl get pods -A
NAMESPACE     NAME                                                                         READY   STATUS      RESTARTS      AGE
kube-system   cloud-controller-manager-ip-10-250-208-15.ap-northeast-1.compute.internal    1/1     Running     0             2m21s
kube-system   cloud-controller-manager-ip-10-250-218-216.ap-northeast-1.compute.internal   1/1     Running     0             2m35s
kube-system   cloud-controller-manager-ip-10-250-218-59.ap-northeast-1.compute.internal    1/1     Running     3 (13h ago)   14h
kube-system   etcd-ip-10-250-208-15.ap-northeast-1.compute.internal                        1/1     Running     0             2m55s
kube-system   etcd-ip-10-250-218-216.ap-northeast-1.compute.internal                       1/1     Running     0             2m47s
kube-system   etcd-ip-10-250-218-59.ap-northeast-1.compute.internal                        1/1     Running     1 (13h ago)   13h
kube-system   helm-install-rke2-canal-4h766                                                0/1     Completed   0             14h
kube-system   helm-install-rke2-coredns-kslgl                                              0/1     Completed   0             14h
kube-system   helm-install-rke2-ingress-nginx-tqtvf                                        0/1     Completed   0             14h
kube-system   helm-install-rke2-metrics-server-c4gm7                                       0/1     Completed   0             14h
kube-system   kube-apiserver-ip-10-250-208-15.ap-northeast-1.compute.internal              1/1     Running     0             2m34s
kube-system   kube-apiserver-ip-10-250-218-216.ap-northeast-1.compute.internal             1/1     Running     0             2m41s
kube-system   kube-apiserver-ip-10-250-218-59.ap-northeast-1.compute.internal              1/1     Running     1 (13h ago)   13h
kube-system   kube-controller-manager-ip-10-250-208-15.ap-northeast-1.compute.internal     1/1     Running     0             2m31s
kube-system   kube-controller-manager-ip-10-250-218-216.ap-northeast-1.compute.internal    1/1     Running     0             2m44s
kube-system   kube-controller-manager-ip-10-250-218-59.ap-northeast-1.compute.internal     1/1     Running     3 (13h ago)   14h
kube-system   kube-proxy-ip-10-250-208-15.ap-northeast-1.compute.internal                  1/1     Running     0             2m31s
kube-system   kube-proxy-ip-10-250-218-216.ap-northeast-1.compute.internal                 1/1     Running     0             3m12s
kube-system   kube-proxy-ip-10-250-218-59.ap-northeast-1.compute.internal                  1/1     Running     1 (14h ago)   14h
kube-system   kube-scheduler-ip-10-250-208-15.ap-northeast-1.compute.internal              1/1     Running     0             2m35s
kube-system   kube-scheduler-ip-10-250-218-216.ap-northeast-1.compute.internal             1/1     Running     0             2m41s
kube-system   kube-scheduler-ip-10-250-218-59.ap-northeast-1.compute.internal              1/1     Running     2 (13h ago)   14h
kube-system   rke2-canal-htbq9                                                             2/2     Running     0             3m15s
kube-system   rke2-canal-hw6hb                                                             2/2     Running     2 (14h ago)   14h
kube-system   rke2-canal-wkqvh                                                             2/2     Running     0             3m24s
kube-system   rke2-coredns-rke2-coredns-869b5d56d4-8jjx4                                   1/1     Running     0             3m15s
kube-system   rke2-coredns-rke2-coredns-869b5d56d4-v78sh                                   1/1     Running     1 (14h ago)   14h
kube-system   rke2-coredns-rke2-coredns-autoscaler-5b947fbb77-w7csq                        1/1     Running     0             14h
kube-system   rke2-ingress-nginx-controller-blghm                                          1/1     Running     0             2m33s
kube-system   rke2-ingress-nginx-controller-fkwcn                                          1/1     Running     0             2m14s
kube-system   rke2-ingress-nginx-controller-njb6f                                          1/1     Running     0             13h
kube-system   rke2-metrics-server-6564db4569-4qfvg                                         1/1     Running     0             13h
```
