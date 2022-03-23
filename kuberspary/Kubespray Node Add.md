# Kubespray Node Add

- 기존 Kubespray를 통하여 설치 된 Cluster에 신규 Node를 추가하는 방안에 대해서 설명 합니다.

- 기존 Node 형상
```
$ kubectl get nodes
NAME                 STATUS   ROLES                  AGE    VERSION
controlpalne-prd-1   Ready    control-plane,master   131m   v1.21.6
controlpalne-prd-2   Ready    control-plane,master   130m   v1.21.6
controlpalne-prd-3   Ready    control-plane,master   130m   v1.21.6
worker-prd-1         Ready    worker                 129m   v1.21.6
worker-prd-2         Ready    worker                 129m   v1.21.6
worker-prd-3         Ready    worker                 129m   v1.21.6
```

## 1. Kubespray Host 파일 수정

- 기존에 설치 된 Directory의 inventory에서 worker-prd-4를 추가

```
$ cat inventory/mycluster/inventory.ini
[all]
controlpalne-prd-1 ansible_host=10.250.205.112  ip=10.250.205.112 etcd_member_name=etcd1
controlpalne-prd-2 ansible_host=10.250.199.224  ip=10.250.199.224 etcd_member_name=etcd2
controlpalne-prd-3 ansible_host=10.250.196.143  ip=10.250.196.143 etcd_member_name=etcd3
worker-prd-1 ansible_host=10.250.194.64  ip=10.250.194.64
worker-prd-2 ansible_host=10.250.192.140  ip=10.250.192.140
worker-prd-3 ansible_host=10.250.202.107  ip=10.250.202.107
worker-prd-4 ansible_host=10.250.202.134  ip=10.250.202.134

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
worker-prd-4

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr
```


## 2. Kubespray Node 추가

- Ansible 명령을 통하여 Node 추가

```
$ ansible-playbook -i inventory/mycluster/inventory.ini ./cluster.yml --flush-cache -b -v   --private-key=~/.ssh/id_rsa -l worker-prd-4
```

## 3. Node 확인


```
$ kubectl label node worker-prd-4 node-role.kubernetes.io/worker=worker
$ kubectl get nodes
NAME                 STATUS   ROLES                  AGE    VERSION
controlpalne-prd-1   Ready    control-plane,master   131m   v1.21.6
controlpalne-prd-2   Ready    control-plane,master   130m   v1.21.6
controlpalne-prd-3   Ready    control-plane,master   130m   v1.21.6
worker-prd-1         Ready    worker                 129m   v1.21.6
worker-prd-2         Ready    worker                 129m   v1.21.6
worker-prd-3         Ready    worker                 129m   v1.21.6
worker-prd-4         Ready    worker                 96s    v1.21.6

```
