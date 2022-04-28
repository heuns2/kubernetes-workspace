# Vault CLI Install & 연동 확인

- 본 문서는 Vault CLI를 Bastion에 설치하여 K8S Helm으로 설치 된 Vault Server에 접근하는 방안에 대하여 기술한 문서입니다.

#### 1. Vault CLI Install

```
$ sudo yum install -y yum-utils
$ sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
$ sudo yum -y install vault
```

#### 2. Vault 연동 확인

- Version 확인

```
$ vault version
Vault v1.10.1 (e452e9b30a9c2c8adfa1611c26eb472090adc767)
```

- Login

```
$ export VAULT_ADDR=https://xxx.xxx.com
$ vault login 
$ vault login
Token (will be hidden):
WARNING! The VAULT_TOKEN environment variable is set! This takes precedence
over the value set by this command. To use the value set by this command,
unset the VAULT_TOKEN environment variable or set it to the token displayed
below.

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                xxxxxxxxx
token_accessor       xxxxxxxxx
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]

# Key 확인
$ vault secrets list -detailed
Path          Plugin       Accessor              Default TTL    Max TTL    Force No Cache    Replication    Seal Wrap    External Entropy Access    Options           Description                                                UUID
----          ------       --------              -----------    -------    --------------    -----------    ---------    -----------------------    -------           -----------                                                ----
cubbyhole/    cubbyhole    cubbyhole_sadzxc    n/a            n/a        false             local          false        false                      map[]             per-token private secret storage                           3d6e40d5-5344-25bb-ab1f-6e8b5b982f9a
identity/     identity     identity_213d2f     system         system     false             replicated     false        false                      map[]             identity store                                             c3641ac6-2779-5692-9597-0bb723cb72b3
kv/           kv           kv_esdsaz7e           system         system     false             replicated     false        false                      map[version:2]    n/a                                                        29ec444e-f914-b635-c8e3-14dd07145139
secret/       kv           kv_13das1f3b           system         system     false             replicated     false        false                      map[]             n/a                                                        9d7b9f4f-63b0-65ee-ffb3-cf8c4c2f53c1
sys/          system       system_dd123asd24b       n/a            n/a        false             replicated     false        false                      map[]             system endpoints used for control, policy and debugging    zcdqw-7dc3-a591-afcf-zqwesd
```

