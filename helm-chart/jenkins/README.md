# Jenkins Install

## 1. Prerequisites

### 1.1. Software

- Kubernetes
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
$ helm search repo jenkinsci/jenkins
$ helm pull jenkinsci/jenkins --version 3.11.7 --untar
```

### 2.3. Jenkins 사용 Volume 생성
- Jenkins Build History, Plugin 등을 저장하기 위해 /data/jenkins-volume/ Persistence Volume 생성
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: jenkins
spec:
  accessModes:
    - ReadWriteMany
  volumeMode: Filesystem
  resources:
    requests:
      storage: 20Gi
  storageClassName: "longhorn"
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

- kubectl  apply

```
$ kubectl apply -f jenkins-sa.yaml
```

### 2.5. Storage Node로 Affinity 설정

```
$ cat affinity-values.yaml
controller:
  affinity:
   nodeAffinity:
     requiredDuringSchedulingIgnoredDuringExecution:
       nodeSelectorTerms:
       - matchExpressions:
         - key: node-type
           operator: NotIn
           values:
           - "router"
           - "controlplane"
  nodeSelector:
    node-type: "storage"

```

### 2.6.  Helm Jenkins Chart 설치

```
$ helm upgrade --install jenkins . \
--namespace=jenkins \
--set controller.jenkinsUrl=https://jenkins.heun.leedh.xyz \
--set persistence.existingClaim="jenkins-pvc" \
--set persistence.accessMode="ReadWriteMany" \
--set serviceAccount.name=jenkins \
--set serviceAccount.create=false \
-f values.yaml,affinity-values.yaml
```

- 아래와 같은 에러메세지가 발생 할 경우 values.yaml에 아래 라인을 주석 해제
	- /var/jenkins_config/apply_config.sh: 4: cannot create /var/jenkins_home/jenkins.install.UpgradeWizard.state: Permission denied

```
  podSecurityContextOverride:
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
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: "jenkins.heun.leedh.xyz"
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


### 4. 이슈 사항 확인

### 4.1. Gitlab 연동 시 SSL Certicate (신뢰하는 인증서) 장애가 발생 시 

```
unable to access 'https://gitlab.eks.leedh.cloud/root/my-test.git/': server certificate verification failed. CAfile: none CRLfile: none
```

- 아래 설정을 values.yaml에 추가 또는 set

```
  containerEnv:
  - name: "GIT_SSL_NO_VERIFY"
    value: "1"

  envVars:
  - name: "GIT_SSL_NO_VERIFY"
    value: "1"
```




