# Key/Value Vault Helm Install

## Prerequisites
-   Helm 3.0+  - This is the earliest version of Helm tested. It is possible it works with earlier versions but this chart is untested for those versions.
-   Kubernetes 1.16+  - This is the earliest version of Kubernetes tested. It is possible that this chart works with earlier versions but it is untested.

## 1. Vault Helm Install

- Vault Helm Repo Add & Update

```
$ helm repo add hashicorp https://helm.releases.hashicorp.com
$ helm repo update
```

- Vault Helm Chart Download

```
# 설치 가능 버전 확인
$ helm search repo hashicorp/vault --versions
$ helm pull hashicorp/vault --version=0.18.0 --untar
```

- Affinity 설정

```
$ cat affinity-values.yaml
injector:
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

server:
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

- Vault Helm Install

```
$ kubectl create ns vault
$ helm upgrade --install vault . --namespace=vault \
--set server.ha.enabled=true \
--set server.ha.raft.enabled=true \
--set dataStorage.storageClass=longhorn \
--set accessMode=ReadWriteMany \
-f values.yaml,affinity-values.yaml
```

## 2. Vault 초기화 & 잠금 해제

- 초기화 되지 않은 상태로 Vault를 실행 할 경우 아래 Pod 형상과 로그가 출력 됨

```
$ kubectl -n vault get pods
NAME                                    READY   STATUS    RESTARTS   AGE
vault-0                                 0/1     Running   0          78s
vault-1                                 0/1     Running   0          77s
vault-2                                 0/1     Running   0          76s
vault-agent-injector-6c9fd744f4-lzk78   1/1     Running   0          79s

2022-04-01T03:56:50.662Z [INFO]  core: Initializing VersionTimestamps for core
2022-04-01T03:56:58.264Z [INFO]  core: security barrier not initialized
```


### 2.1. Vault 초기화

- Vault Init을 실행하여 초기화

```
kubectl -n vault exec -ti vault-0 -- vault operator init
Unseal Key 1: yXQigeHvNM4Dk/8US5L0wKHBJFK71tRUT7vpiaKkKSjj
Unseal Key 2: wCIAOmQ8eTwN2byjC2edlhr4I9OdC3+1IWySNricrBS9
Unseal Key 3: AxaG16pNrxVpgg5CrS4uF5tpzhRDVMP/QY4WBuq31XSd
Unseal Key 4: CkCkbC+e4udnyE317dtHQSBQyZVliWgeL1ltufCPUEjD
Unseal Key 5: k6tv8CRXnCTnjLNUIaBQCc5C5i659ovUnUG1FqeGknTt

Initial Root Token: s.6sBw8kQxVyOA9QfjCcmbHfIb

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated master key. Without at least 3 keys to
reconstruct the master key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.

```

### 2.2. Vault 잠금 해제
- Unseal Key 정보 들을 잠금 해제 합니다.

```
$ kubectl -n vault exec -ti vault-0 -- vault operator unseal
Unseal Key (will be hidden):
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    1/3
Unseal Nonce       5f9a0c47-2d14-2591-3a96-4054c324969b
Version            1.9.0
Storage Type       raft
HA Enabled         true

$ kubectl -n vault exec -ti vault-0 -- vault operator unseal
Unseal Key (will be hidden):
Key                Value
---                -----
Seal Type          shamir
Initialized        true
Sealed             true
Total Shares       5
Threshold          3
Unseal Progress    2/3
Unseal Nonce       5f9a0c47-2d14-2591-3a96-4054c324969b
Version            1.9.0
Storage Type       raft
HA Enabled         true

$ kubectl -n vault exec -ti vault-0 -- vault operator unseal
Unseal Key (will be hidden):
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.9.0
Storage Type            raft
Cluster Name            vault-cluster-3a0dc29f
Cluster ID              c881d6a1-a001-0e22-8df2-2ab11020d0ed
HA Enabled              true
HA Cluster              n/a
HA Mode                 standby
Active Node Address     <none>
Raft Committed Index    25
Raft Applied Index      25

$ kubectl -n vault exec -ti vault-0 -- vault operator unseal
Unseal Key (will be hidden):
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.9.0
Storage Type            raft
Cluster Name            vault-cluster-3a0dc29f
Cluster ID              c881d6a1-a001-0e22-8df2-2ab11020d0ed
HA Enabled              true
HA Cluster              n/a
HA Mode                 standby
Active Node Address     <none>
Raft Committed Index    25
Raft Applied Index      25

$ kubectl -n vault exec -ti vault-0 -- vault operator unseal
Unseal Key (will be hidden):
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.9.0
Storage Type            raft
Cluster Name            vault-cluster-3a0dc29f
Cluster ID              c881d6a1-a001-0e22-8df2-2ab11020d0ed
HA Enabled              true
HA Cluster              n/a
HA Mode                 standby
Active Node Address     <none>
Raft Committed Index    25
Raft Applied Index      25
```


## 3. Vault Clustering 설정

- 1번 Vault Service를 초기화 시키고, 나머지 2대의 Vault  Service를 Join하여 Clustering 

```
$ kubectl -n vault exec -ti vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
Key       Value
---       -----
Joined    true

$ kubectl -n vault exec -ti vault-1 -- vault operator unseal

$ kubectl -n vault exec -ti vault-2 -- vault operator raft join http://vault-0.vault-internal:8200
Key       Value
---       -----
Joined    true

$ kubectl -n vault exec -ti vault-2 -- vault operator unseal

```

- Vault의 Peer List 확인

```
$ kubectl -n vault exec -ti vault-0 -- vault operator raft list-peers
Node                                    Address                        State       Voter
----                                    -------                        -----       -----
bdb0996a-023d-e95b-014c-e1edd474ca25    vault-0.vault-internal:8201    leader      true
901fcdfe-2f75-8d6b-9ee4-e4e28612b80d    vault-1.vault-internal:8201    follower    true
8ff24622-b10f-eff3-7fc6-38fa79c44452    vault-2.vault-internal:8201    follower    true
```



## 4. Vault 설치 확인

- Valut CLI를 Key Value 저장소 접근 확인

```
# 현재 secrets 확인
$ kubectl -n vault exec -ti vault-0 -- vault secrets list -detailed
Path          Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    External Entropy Access    Options    Description                                                UUID
----          ------       --------              -----------    -------    --------------    -----------    ---------    -----------------------    -------    -----------                                                ----
cubbyhole/    cubbyhole    cubbyhole_5475d298    n/a            n/a        false             local          false        false                      map[]      per-token private secret storage                           0cad2f2a-541a-288d-8bd6-3a40247694e7
identity/     identity     identity_da24f494     system         system     false             replicated     false        false                      map[]      identity store                                             7043e3ff-daf8-edd6-37c1-1475a357cd7d
sys/          system       system_fac1e87c       n/a            n/a        false             replicated     false        false                      map[]      system endpoints used for control, policy and debugging    a85fea08-f4ed-b1c0-4505-40378c8259c9

# secret에 kv 사용 실행
$ kubectl -n vault exec -ti vault-0 -- vault secrets enable -path=secret/ kv

# kv put
$ kubectl -n vault exec -ti vault-0 -- vault kv put secret/customer/leedh name="leedh Inc." \
        contact_email="ehdgus6600@google.com"
# kv put
$ kubectl -n vault exec -ti vault-0 -- vault kv get secret/customer/leedh
```
