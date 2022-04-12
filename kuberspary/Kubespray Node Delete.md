# Kubespray Node Delete

- Kubespray를 통하여 설치 된 Cluster에 기존 Node를 제거 방안에 대해서 설명 합니다.

## Kubespray Node 삭제

- 삭제 전 Node 형상

```
NAME    STATUS   ROLES                  AGE     VERSION
node1   Ready    control-plane,master   5h41m   v1.21.6
node2   Ready    control-plane,master   5h41m   v1.21.6
node3   Ready    control-plane,master   5h41m   v1.21.6
node4   Ready    <none>                 31s   v1.21.6
```


- Kubespray Source Code Directory로 이동

```
$ cd kubespray-2.17.1
```

- Node Drain 명령 실행

```
$ kubectl drain node2 --ignore-daemonsets --delete-emptydir-data

# Drain 후 Node 형상
NAME    STATUS   ROLES                  AGE    VERSION
node1   Ready    control-plane,master   6h10m   v1.21.6
node2   Ready    control-plane,master   6h10m   v1.21.6
node3   Ready    control-plane,master   6h10m   v1.21.6
node4   NotReady,SchedulingDisabled    <none>  93s    v1.21.6
```


- Node 제거 명령 실행

```
$ ansible-playbook -i inventory/mycluster/inventory.ini ./remove-node.yml --flush-cache -v --private-key=~/.ssh/id_ras --become --become-user=root --extra-vars "node=node4"

# 제거 대상의 node4 확인
PLAY [node4] ***************************************************************************************************************************************************************************************
Tuesday 12 April 2022  08:11:22 +0000 (0:00:00.054)       0:00:00.225 *********
[Confirm Execution]
Are you sure you want to delete nodes state? Type 'yes' to delete nodes.: 


# Node 제거 후 Node 형상
NAME    STATUS   ROLES                  AGE    VERSION
node1   Ready    control-plane,master   6h21m   v1.21.6
node2   Ready    control-plane,master   6h21m   v1.21.6
node3   Ready    control-plane,master   6h21m   v1.21.6
```

- 다시 삭제 한 Node를 추가 할 경우 추가 대상의 Node에서 containerd, docker restart가 필요 할 수 있음
