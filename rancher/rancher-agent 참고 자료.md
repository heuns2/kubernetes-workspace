# Rancher Agent 설정

- Rancher Agent를 설정하여 Rancher Server와 통신하여 Rancher Server UI에서 현재 존재하고 있는 Cluster 정보를 획득, 관리 하는 절차 방안에 대하여 기술한 문서입니다.

## 1. Rancher Main에서 Agent 설정

- Rancher UI에 접근하여 [Import Existing] 버튼을 클릭 합니다.

![rancer-ui-1][rancer-ui-1]

[rancer-ui-1]:./images/rancher-agent-ui-1.PNG


- Cluster Import 화면에서 [Import any Kubernetes cluster] 버튼을 클릭 합니다.


![rancer-ui-2][rancer-ui-2]

[rancer-ui-2]:./images/rancher-agent-ui-2.PNG

- Cluster 정보 입력 후 Create 버튼을 클릭합니다.

![rancer-ui-3][rancer-ui-3]

[rancer-ui-3]:./images/rancher-agent-ui-4.PNG
 
- 화면에서 명시 된 명령어 중 certificate signed by unknown authority 단계를 복사하여 Kubespray 기반의 Cluster에 Apply 합니다.

![rancer-ui-4][rancer-ui-4]

[rancer-ui-4]:./images/rancher-agent-ui-3.PNG


- Pod 정상화 확인

```
$ kubectl -n cattle-system get pods
NAME                                    READY   STATUS        RESTARTS   AGE
cattle-cluster-agent-65bbdb474f-qwrvg   1/1     Running       0          32s

```

- Join 된 Cluster 확인

![rancer-ui-5][rancer-ui-5]

[rancer-ui-5]:./images/rancher-agent-ui-5.PNG



## 2. Issue

- DNS를 찾지 못 할 경우 kubectl 명령 수행 대상의 Bastion 환경에서 /etc/hosts에 rancher가 등록 되어있어야 합니다.
- DNS를 찾지 못 할 경우 아래 명령을 수행하여 Pod의 DNS를 변경해야 합니다. 

```
$ kubectl -n cattle-system patch  deployments cattle-cluster-agent --patch '{
    "spec": {
        "template": {
            "spec": {
                "hostAliases": [
                    {
                      "hostnames":
                      [
                        "rancher.xxx.xxx.xxx"
                      ],
                      "ip": "xxx.xx.xxx.xxx"
                    }
                ]
            }
        }
    }
}'
```
