# Jenkins 설치 (Helm v3)

## 1. Prerequisites

### 1.1. Software

- Docker Engine <<< ???? 왜 사전 조건인지 확인 필요
- Kubernetes (본 가이드는 EKS 환경을 사용)
- Helm CLI (https://helm.sh/docs/intro/install/)


## 2. Jenkins 설치

### 2.1. namespace 생성
- Jenkins 관리용 namespace 생성

```
$ kubectl create namespace jenkins
```

### 2.2. Helm Install & Jenkins 설정
- Helm Jenkins Repo 추가 & 동기화

```
$ helm repo add jenkinsci https://charts.jenkins.io
$ helm repo update
```

- Helm Jenkins Helm Chart 다운로드

```
$ helm pull jenkinsci/jenkins --version 3.8.5 --untar
```


### 2.3. Jenkins 사용 Volume 생성
- Jenkins Build History, Plugin 등을 저장하기 위해 /data/jenkins-volume/ Persistence Volume 생성

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jenkins-pv
  namespace: jenkins
  annotations:
    pv.beta.kubernetes.io/gid: "1000"
spec:
  storageClassName: gp2
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 20Gi
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/jenkins-volume/
```

- Persistence Volume 생성

```
$ kubectl apply -f jenkins-pv.yaml
$ kubectl -n jenkins get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                                                        STORAGECLASS   REASON   AGE
jenkins-pv                                 20Gi       RWO            Retain           Available                                                                gp2                     31s
```

### 2.4. Jenkins 사용 Service Account 생성
- Cluster 전체에서 역할을 정의를 위해 ClusterRole, ClusterRoleBinbing, ServiceAccount 생성 (모든 Namespace에 접근 가능)

```
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: jenkins
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: jenkins
rules:
- apiGroups:
  - '*'
  resources:
  - statefulsets
  - services
  - replicationcontrollers
  - replicasets
  - podtemplates
  - podsecuritypolicies
  - pods
  - pods/log
  - pods/exec
  - podpreset
  - poddisruptionbudget
  - persistentvolumes
  - persistentvolumeclaims
  - jobs
  - endpoints
  - deployments
  - deployments/scale
  - daemonsets
  - cronjobs
  - configmaps
  - namespaces
  - events
  - secrets
  verbs:
  - create
  - get
  - watch
  - delete
  - list
  - patch
  - update
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
  - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: jenkins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:serviceaccounts:jenkins
```

- apply

```
$ kubectl apply -f jenkins-sa.yaml
```


### 2.5.  Helm Jenkins Chart 설치

```
$ helm install jenkins jenkinsci/jenkins \
--namespace=jenkins \
--set controller.jenkinsUrl=https://xxx.xxx.leedh.cloud\
--set persistence.storageClass=gp2 \
--set serviceAccount.name=jenkins \
--set serviceAccount.create=false
```

- 아래와 같은 에러메세지가 발생 할 경우 values.yaml에 아래 라인을 수정하여 조치
	- /var/jenkins_config/apply_config.sh: 4: cannot create /var/jenkins_home/jenkins.install.UpgradeWizard.state: Permission denied

```
runAsUser: 1000
runAsGroup: 1000
runAsNonRoot: true
fsGroup: 1000
fsGroupChangePolicy: "OnRootMismatch"
```

### 2.6. Jenkins Ingress 설정

- 인증서 적용을 위해 Secret 생성 cert, key 파일은 harbor 설치 시 사용한 인증서 활용

```
$ kubectl create -n jenkins secret tls jenkins-tls --key eks.leedh.cloud.key --cert eks.leedh.cloud.crt
```

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins-ingress
  namespace: jenkins
  annotations:
    kubernetes.io/ingress.class: "nginx"
    ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    #nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: "xxx.xxx.leedh.cloud"
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: jenkins
            port:
              number: 8080
  tls:
  - hosts:
    - xxx.xxx.leedh.cloud
    secretName: jenkins-tls

```

### 3. Jenkins UI 확인

- 초기 Password Get

```
$ kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/chart-admin-password && echo
xxxxxxxxxxxxxxx
```

- Jenkins UI 확인

![jenkins-1][jenkins-1]

[jenkins-1]:./images/jenkins-1.PNG

- Jenkins https 인증서 적용 확인

![jenkins-2][jenkins-2]

[jenkins-2]:./images/jenkins-2.PNG

