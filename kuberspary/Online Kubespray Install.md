# Online Kubespray Install

## Requirements
- docker version is 18.09, 19.03 and 20.10. The recommended docker version is 20.10
- Minimum required version of Kubernetes is v1.21
- Ansible v2.9.x, Ansible v2.10.x(실험적)
- 대상 서버는 IPv4 전달을 허용하도록 구성, IPv6을 사용 할 경우 IPv6도 허용 하도록 구성
- 인터넷 망이 되지 않으면 별도의 Offline 구성이 필요 (Local Repo, Private Registry)
- Root 권한으로 설치
- Master 3대, Work Node 3대 구성 Sample

## 1. 설치 준비

### 1.1. Source Code Clone OR Download

- Git Clone 방식

```
$ git clone https://github.com/kubernetes-sigs/kubespray.git
$ git tag
$ git checkout tags/v2.17.1
```

- Download 방식 (본 문서는 해당 방안을 이용)

```
$ curl -LO https://github.com/kubernetes-sigs/kubespray/archive/refs/tags/v2.17.1.tar.gz
$ tar xvf v2.17.1.tar.gz
```

### 1.2. Dependency 설치와 Config 설정

- Python3 설치 & Kubespray 사용 용도의 Dependency 설치

```
# kubespray 소스코드 파일 디렉토리로 이동
$ cd /home/centos/kubespray/kubespray-2.17.1
$ sudo yum install python3-pip
$ sudo pip3 install -r requirements.txt
WARNING: Running pip install with root privileges is generally not a good idea. Try `pip3 install --user` instead.
Collecting ansible==3.4.0 (from -r requirements.txt (line 1))
  Downloading https://files.pythonhosted.org/packages/a9/f3/7e7e3647d58b266768a000b5830c7fca7c02eac4e724e9b23309b735f9b2/ansible-3.4.0.tar.gz (31.9MB)
    100% |████████████████████████████████| 31.9MB 42kB/s
Collecting ansible-base==2.10.11 (from -r requirements.txt (line 2))
  Downloading https://files.pythonhosted.org/packages/a0/93/9d8c26b2a4e1d2b48802a577ca6ada084f58e576f67917c9e28858bf747b/ansible-base-2.10.11.tar.gz (6.0MB)
    100% |████████████████████████████████| 6.0MB 224kB/s
Collecting cryptography==2.8 (from -r requirements.txt (line 3))
  Downloading https://files.pythonhosted.org/packages/45/73/d18a8884de8bffdcda475728008b5b13be7fbef40a2acc81a0d5d524175d/cryptography-2.8-cp34-abi3-manylinux1_x86_64.whl (2.3MB)
... 생략

# ansible 버전 확인
$ ansible --version
ansible 2.10.11
  config file = /home/centos/kubespray/kubespray-2.17.1/ansible.cfg
  configured module search path = ['/home/centos/kubespray/kubespray-2.17.1/library']
  ansible python module location = /usr/local/lib/python3.6/site-packages/ansible
  executable location = /usr/local/bin/ansible
  python version = 3.6.8 (default, Nov 16 2020, 16:55:22) [GCC 4.8.5 20150623 (Red Hat 4.8.5-44)]
```

- 모든 Node에 들어가 Swap, 브릿지 등 설정

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

- Bastion Node에서 Key Pair 생성 후 다른 모든 Node에 authorized_key 생성

```
# Bastion VM에서 keygen  
$ sudo su
$ ssh-keygen -t rsa

# 나머지 모든 Node에 SSH 접근하여 모든 Node에 키 등록
$ sudo su
$ cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys  
$ cat ~/.ssh/authorized_keys
```

- Host 등록 Config File 설정

```
# kubespray 소스코드 파일 디렉토리로 이동
$ cd /home/centos/kubespray/kubespray-2.17.1
$ cp -rfp inventory/sample/ inventory/mycluster
$ cat inventory/mycluster/inventory.ini
[all]
controlpalne-prd-1 ansible_host=10.250.205.112  ip=10.250.205.112 etcd_member_name=etcd1
controlpalne-prd-2 ansible_host=10.250.199.224  ip=10.250.199.224 etcd_member_name=etcd2
controlpalne-prd-3 ansible_host=10.250.196.143  ip=10.250.196.143 etcd_member_name=etcd3
worker-prd-1 ansible_host=10.250.194.64  ip=10.250.194.64
worker-prd-2 ansible_host=10.250.192.140  ip=10.250.192.140
worker-prd-3 ansible_host=10.250.202.107  ip=10.250.202.107

[kube_control_plane]
controlpalne-prd-1
controlpalne-prd-2
controlpalne-prd-3

[etcd]
controlpalne-prd-1
controlpalne-prd-2
controlpalne-prd-3

[kube_node]
controlpalne-prd-1
controlpalne-prd-2
controlpalne-prd-3
worker-prd-1
worker-prd-2
worker-prd-3

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr
```

- Runtime 변경 설정
```
# inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml 파일 수정
container_manager: docker > container_manager: containerd로 변경 저장
```

- ETCD 변경 설정
```
# inventory/mycluster/group_vars/etcd.yml 파일 수정
etcd_deployment_type: docker > etcd_deployment_type: host로 변경 저장
```

## 2. Kubespray를 통한 K8S 설치


### 2.1. Ansible을 통하여 K8S 실행

```
# 디렉토리 이동
$ cd /home/centos/kubespray/kubespray-2.17.1
$ ansible-playbook -i inventory/mycluster/inventory.ini ./cluster.yml --flush-cache -b -v \
  --private-key=~/.ssh/id_rsa
```

-  Bastion Node에서 kubectl 다운 및 자동 완성 기능 ON

```
$ curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

$ chmod +x kubectl
$ mv kubectl /usr/bin

$ yum install -y bash-completion
$ echo  'source <(kubectl completion bash)' >>~/.bashrc​

$ kubectl  completion bash >/etc/bash_completion.d/kubectl​
```


### 2.2. Ansible을 통하여 K8S 설치 확인


```
$ kubectl get nodes
NAME                 STATUS   ROLES                  AGE    VERSION
controlpalne-prd-1   Ready    control-plane,master   114m   v1.21.6
controlpalne-prd-2   Ready    control-plane,master   113m   v1.21.6
controlpalne-prd-3   Ready    control-plane,master   113m   v1.21.6
worker-prd-1         Ready    <none>                 112m   v1.21.6
worker-prd-2         Ready    <none>                 112m   v1.21.6
worker-prd-3         Ready    <none>                 112m   v1.21.6


$ kubectl get pods -A
NAMESPACE     NAME                                         READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-8575b76f66-5dvjq     1/1     Running   0          110m
kube-system   calico-node-2z4x6                            1/1     Running   0          111m
kube-system   calico-node-4f52d                            1/1     Running   0          111m
kube-system   calico-node-mp52m                            1/1     Running   0          111m
kube-system   calico-node-tlcdt                            1/1     Running   0          111m
kube-system   calico-node-wjwst                            1/1     Running   0          111m
kube-system   calico-node-z9fxx                            1/1     Running   0          111m
kube-system   coredns-8474476ff8-b5zwj                     1/1     Running   0          110m
kube-system   coredns-8474476ff8-jnjkz                     1/1     Running   0          110m
kube-system   dns-autoscaler-7df78bfcfb-cdst8              1/1     Running   0          110m
kube-system   kube-apiserver-controlpalne-prd-1            1/1     Running   0          113m
kube-system   kube-apiserver-controlpalne-prd-2            1/1     Running   0          112m
kube-system   kube-apiserver-controlpalne-prd-3            1/1     Running   0          112m
kube-system   kube-controller-manager-controlpalne-prd-1   1/1     Running   1          113m
kube-system   kube-controller-manager-controlpalne-prd-2   1/1     Running   1          112m
kube-system   kube-controller-manager-controlpalne-prd-3   1/1     Running   1          112m
kube-system   kube-proxy-95v8f                             1/1     Running   0          111m
kube-system   kube-proxy-dljw4                             1/1     Running   0          111m
kube-system   kube-proxy-hwst7                             1/1     Running   0          111m
kube-system   kube-proxy-p7t4q                             1/1     Running   0          111m
kube-system   kube-proxy-rj6kv                             1/1     Running   0          111m
kube-system   kube-proxy-xs72m                             1/1     Running   0          111m
kube-system   kube-scheduler-controlpalne-prd-1            1/1     Running   1          113m
kube-system   kube-scheduler-controlpalne-prd-2            1/1     Running   1          112m
kube-system   kube-scheduler-controlpalne-prd-3            1/1     Running   1          112m
kube-system   nginx-proxy-worker-prd-1                     1/1     Running   0          111m
kube-system   nginx-proxy-worker-prd-2                     1/1     Running   0          111m
kube-system   nginx-proxy-worker-prd-3                     1/1     Running   0          111m
kube-system   nodelocaldns-468fw                           1/1     Running   0          110m
kube-system   nodelocaldns-blr8k                           1/1     Running   0          110m
kube-system   nodelocaldns-lm2gv                           1/1     Running   0          110m
kube-system   nodelocaldns-nrpm6                           1/1     Running   0          110m
kube-system   nodelocaldns-q5lsv                           1/1     Running   0          110m
kube-system   nodelocaldns-vk8gq                           1/1     Running   0          110m
```

- Kubernetes Node에 Worker Role 추가

```
$ kubectl label node worker-prd-1 node-role.kubernetes.io/worker=worker
$ kubectl label node worker-prd-2 node-role.kubernetes.io/worker=worker
$ kubectl label node worker-prd-3 node-role.kubernetes.io/worker=worker

$ kubectl get nodes
NAME                 STATUS   ROLES                  AGE    VERSION
controlpalne-prd-1   Ready    control-plane,master   116m   v1.21.6
controlpalne-prd-2   Ready    control-plane,master   115m   v1.21.6
controlpalne-prd-3   Ready    control-plane,master   115m   v1.21.6
worker-prd-1         Ready    worker                 114m   v1.21.6
worker-prd-2         Ready    worker                 114m   v1.21.6
worker-prd-3         Ready    worker                 114m   v1.21.6
```

