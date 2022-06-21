# ArgoCD Slack Notification 연동

- Argocd Event 발생 시 Slack으로 Alert를 받는 방안에 대하여 설명 합니다.
- 주요 Event Alert 대상은 Sync가 성공, 실패, 진행, Unknown, Degrade, Deploy에 대한 설정입니다.

## 1. Prerequisites (Slack App 설정)

### 1.1. Slack App에서 Argocd가 사용 할 Slack API에 대한 Token을 생성 합니다.

- https://api.slack.com/apps에 접근하여 App을 선택하고 [OAuth & Permission] 버튼을 클릭합니다.
- 하단 BOT Scopes에서 chat:write를 추가하고 Token을 발급하고 해당 Token 값을 복사하여 메모장에 붙여 넣기 합니다. 추 후 configmap과 secret에서 사용 될 예정입니다.


## 2. Argocd Notification 설정

### 2.1. Argocd Notification 배포

- Manifest 파일을 사용하여 Argocd 설치 Namespace에 관련 Deploy를 설치 합니다.

- controller app과 configmaps를 생성합니다.

```
$ kubectl -n argo apply -f argocd-notifications-controller.yaml
$ kubectl -n argo apply -f argocd-notifications-configuration.yaml
```

- Argocd-notifications-controller Deployment Running 상태를 확인 합니다.

```
$ kubectl -n argo get pods | grep notifications-controller
argocd-notifications-controller-84ccc64f96-frcp9   1/1     Running     0          40s
```


- Slack Token을 사용하여 Argocd Notifications Secret을 생성 합니다.

```
$ cat argocd-notifications-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argo
stringData:
  slack-token: xoxb-xxxx


$ kubectl apply -f argocd-notifications-secret.yaml
```

- Argocd Configmaps 수정하여 service.slack에 Token 값을 생성 합니다.

```
$ kubectl -n argo edit cm argocd-notifications-cm
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  service.slack: |
    token: xoxb-xxxxx
```


### 2.2. Argocd Application Modify

- sample-app App을 Sample로 각 Event Trigger 시 argo-deploy로 Alert를 전송하는 Sample입니다. 모든 Application 등록 필요

```
$ kubectl patch applications.argoproj.io sample-app -n argo -p '{"metadata": {"annotations": {"notifications.argoproj.io/subscribe.on-sync-succeeded.slack":"argo-deploy"}}}' --type merge

$ kubectl patch applications.argoproj.io sample-app -n argo -p '{"metadata": {"annotations": {"notifications.argoproj.io/subscribe.on-sync-failed.slack":"argo-deploy"}}}' --type merge

$ kubectl patch applications.argoproj.io sample-app -n argo -p '{"metadata": {"annotations": {"notifications.argoproj.io/subscribe.on-sync-running.slack":"argo-deploy"}}}' --type merge

$ kubectl patch applications.argoproj.io sample-app -n argo -p '{"metadata": {"annotations": {"notifications.argoproj.io/subscribe.on-sync-status-unknown.slack":"argo-deploy"}}}' --type merge

$ kubectl patch applications.argoproj.io sample-app -n argo -p '{"metadata": {"annotations": {"notifications.argoproj.io/subscribe.on-health-degraded.slack":"argo-deploy"}}}' --type merge

$ kubectl patch applications.argoproj.io sample-app -n argo -p '{"metadata": {"annotations": {"notifications.argoproj.io/subscribe.on-deployed.slack":"argo-deploy"}}}' --type merge
```
