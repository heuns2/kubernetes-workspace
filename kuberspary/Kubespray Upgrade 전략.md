# Kubespray Upgrade 전략

- Kubenertes v1.21.1 에서 v1.22.1으로 Upgrade Sample과 Containerd Runimte v1.4.9 -> v.1.4.11에 대한 Upgrade 전략에 대하여 설명 합니다.
- 참고자료: [Kubespray Upgrade](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/upgrades.md)


## 1. Kubespray Upgrade 설정

### 1.1. Limit 값 활용

- limit 옵션으로 특정 Node 1, 2, 3만 Upgrade가 가능합니다.

```
ansible-playbook upgrade-cluster.yml -b -i inventory/mycluster/inventory.ini -e kube_version=v1.22.1 --limit node1,node2,node3
```

### 1.2. 특정 구성 요소 Upgrade

- Kubernetes의 아래 구성  Component들을 선택하여 Upgrade 할 수 있습니다.
	- Docker
	- Containerd
	- etcd
	- kubelet and kube-proxy
	- network_plugin (such as Calico or Weave)
	- kube-apiserver, kube-scheduler, and kube-controller-manager
	- Add-ons (such as KubeDNS)
- [참고자료](https://github.com/kubernetes-sigs/kubespray/blob/master/docs/upgrades.md#component-based-upgrades)

## 2. Kubespray  Upgrade 방안

- 목표 버전은 신규 Kubesparay Git 버전을 다운로드 하고 기존에 사용하였던 mycluster inventory 파일을 그대로 옮깁니다.
- mycluster를 신규 버전의 Github을 기준으로 생성하고 수정하여 inventory.ini, kubeadm_certificate_key.creds만을 별도로 옮기고 기존에 변경 하였던 설정 값들만 변경하여 사용하여도 가능합니다.
- 설치 가능한 Component 버전은 roles/download/defaults/main.yml 디렉토리에 위치하고 있습니다.

- inventory 파일을 전체 옮겨 사용하는 방안

```
$ cp kubespray-2.17.1/inventory/mycluster/ kubespray-2.18.0/inventory/
```

- inventory의 설정 값을 변경하고 

```
$ cd kubespray-2.18.0
$ cp -rfp inventory/sample/ inventory/mycluster

# inventory 관련 파일들을 옮기고 올바르게 작성 되었는지 확인 합니다.
$ cp ../kubespray-2.17.1/inventory/mycluster/inventory.ini inventory/mycluster/inventory.ini
$ cp -rf ../kubespray-2.17.1/inventory/mycluster/credentials/ inventory/mycluster/


# 제이콘텐트리 환경에서는 roles/bootstrap-os/defaults/main.yml 파일 수정
override_system_hostname: true -> override_system_hostname: false로 변경 저장
```

### 2.1. Kubernetes Version Upgrade

- Upgrade 전 Node 상태  기록 합니다.

```
$ kubectl get nodes -o wide
NAME    STATUS  ROLES                  AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
node1   Ready   control-plane,master   15h   v1.21.6   10.250.215.185   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node2   Ready   control-plane,master   15h   v1.21.6   10.250.223.156   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node3   Ready   control-plane,master   15h   v1.21.6   10.250.220.199   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node4   Ready   <none>                 15h   v1.21.6   10.250.210.172   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node5   Ready   <none>                 15h   v1.21.6   10.250.211.88    <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
```

아래 명령어 수행
- --limit 옵션을 이용하면 , 특정 노드만 업그레이드 시킬 수 있습니다.
- --limit 옵션이 없다면 , 전체 노드를 업그레이드 시킵니다.

```
$ ansible-playbook upgrade-cluster.yml -b -i inventory/mycluster/inventory.ini -e kube_version=v1.22.1 --limit node1,node2,node3
```

- Upgrade 후 Node 상태  확인 합니다.
- master node인 node1, node2, node3만 upgrade가 완료 된 것을 확인할 수 있다.

```
# Node 1, 2, 3의 버전 확인
$ kubectl get nodes -o wide
NAME    STATUS  ROLES                  AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
node1   Ready   control-plane,master   15h   v1.22.1   10.250.215.185   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node2   Ready   control-plane,master   15h   v1.22.1   10.250.223.156   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node3   Ready   control-plane,master   15h   v1.22.1   10.250.220.199   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node4   Ready   <none>                 15h   v1.21.6   10.250.210.172   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node5   Ready   <none>                 15h   v1.21.6   10.250.211.88    <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
```

### 2.2. Containerd Version Upgrade

- Upgrade 전 Node 상태  기록 합니다.

```
[centos@ip-10-250-227-204 kubespray-2.17.1]$ kubectl get nodes -o wide
NAME    STATUS  ROLES                  AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
node1   Ready   control-plane,master   15h   v1.22.1   10.250.215.185   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node2   Ready   control-plane,master   15h   v1.22.1   10.250.223.156   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node3   Ready   control-plane,master   15h   v1.22.1   10.250.220.199   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node4   Ready   <none>                 15h   v1.21.6   10.250.210.172   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
node5   Ready   <none>                 15h   v1.21.6   10.250.211.88    <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
```

- Upgrade 실행  node1,node2,node3

```
$ ansible-playbook -b -i inventory/mycluster/inventory.ini upgrade-cluster.yml --tags=containerd -e container_manager=containerd -e  containerd_version=1.4.12 --limit node1,node2,node3
```

- Upgrade 전 Containerd 버전을 확인 합니다.

```
$ kubectl get nodes -o wide
NAME    STATUS   ROLES                  AGE     VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
node1   Ready    control-plane,master   2d15h   v1.22.1   10.250.215.185   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.12
node2   Ready    control-plane,master   2d15h   v1.22.1   10.250.223.156   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.12
node3   Ready    control-plane,master   2d15h   v1.22.1   10.250.220.199   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.12
node4   Ready    <none>                 2d15h   v1.21.6   10.250.210.172   <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.12
node5   Ready    <none>                 2d15h   v1.21.6   10.250.211.88    <none>        CentOS Linux 7 (Core)   3.10.0-1127.19.1.el7.x86_64   containerd://1.4.9
```
