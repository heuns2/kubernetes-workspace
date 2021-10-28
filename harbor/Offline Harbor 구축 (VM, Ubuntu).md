# Offline Harbor 구축 (VM, Ubuntu)

## 1. Prerequisites

### 1.1. Hardware

- Minimum: 2 CPU/4GB Memory/40GB Disk
- Recommended 4CPU/8GB Memory/160GB Disk

### 1.2. Software
- Docker engine Version 17.06.0-ce+ or higher (https://docs.docker.com/engine/install/)
- Docker Compose Version 1.18.0 or higher (https://docs.docker.com/compose/install/)
- Openssl Latest is preferred (인증서 생성 용)

### 1.3. firewall

- 80/443 
	- Harbor portal and core API accept HTTPS/HTTP 용 Port Open
- 4443
	- Notary 사용 시 Port Open

## 2. Installer Download

### 2.1. Harbor Offline Package를 Download하여 Tar 압축 해제

- 다운로드 링크
	- https://github.com/goharbor/harbor/tags

```
# 압축 해제
$  tar xvf harbor.v2.2.4.tar.gz
```

## 3. 인증서 생성 및 설정 - HTTPS 활성화 

### 3.1.  인증서 생성 Flow

- Generate a CA certificate private key

```
$ openssl  genrsa -out ca.key 4096
```

- Generate the CA certificate

```
$ $ openssl req -x509 -new -nodes -sha512 -days 3650 \
 -subj "/C=CN/ST=leedh/L=leedh/O=leedh/OU=leedh/CN=*.eks.leedh.cloud" \
 -key ca.key \
 -out ca.crt
```


### 3.2. Generate a Server Certificate

- Generate a private key

```
$ openssl genrsa -out eks.leedh.cloud.key 4096
```

- Generate a certificate signing request (CSR).

```
$ openssl req -sha512 -new \
    -subj "/C=CN/ST=leedh/L=leedh/O=leedh/OU=leedh/CN=*.eks.leedh.cloud" \
    -key eks.leedh.cloud.key \
    -out eks.leedh.cloud.csr 
```

- Generate an x509 v3 extension file.

```
$ cat > v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=*.eks.leedh.cloud
EOF
```


- Use the v3.ext file to generate a certificate for your Harbor host

```
$ openssl x509 -req -sha512 -days 3650 \
    -extfile v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in eks.leedh.cloud.csr \
    -out eks.leedh.cloud.crt
```

- 생성 한 인증서 Check

```
$ openssl x509 -noout -text -in eks.leedh.cloud.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            44:63:43:34:0e:2b:ac:69:5f:4a:c8:f3:9f:c3:66:aa:de:0d:ec:56
        Signature Algorithm: sha512WithRSAEncryption
        Issuer: C = CN, ST = leedh, L = leedh, O = leedh, OU = leedh, CN = *.eks.leedh.cloud
        Validity
            Not Before: Oct 28 05:12:15 2021 GMT
            Not After : Oct 26 05:12:15 2031 GMT
        Subject: C = CN, ST = leedh, L = leedh, O = leedh, OU = leedh, CN = *.eks.leedh.cloud
```

### 3.3. 인증서 설정

- The Docker daemon interprets `.crt` files as CA certificates and `.cert` files as client certificates. 
- Docker daemon 에서 사용 가능하도록 변환

```
$ openssl x509 -inform PEM -in eks.leedh.cloud.crt -out eks.leedh.cloud.cert
```

- Docker에서 생성한 인증서를 사용 하도록 변경

```
$ sudo cp eks.leedh.cloud.cert /etc/docker/certs.d/eks.leedh.cloud/
$ sudo cp eks.leedh.cloud.key /etc/docker/certs.d/eks.leedh.cloud/
$ sudo cp ca.crt /etc/docker/certs.d/eks.leedh.cloud/

$ systemctl restart docker
$ docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

## 4. Harbor Config 설정 변경

- 크게 아래 설정을 변경

```
hostname: harbor.eks.leedh.cloud
https:
  certificate: /home/leedh/workspace/harbor/harbor/eks.leedh.cloud.cert
  private_key: /home/leedh/workspace/harbor/harbor/eks.leedh.cloud.key

harbor_admin_password: leedh1234
data_volume: /home/leedh/data
```

## 5. Harbor 설치

- Helm Chart도 사용 할 것임으로 chartmuseum 활성화

```
$ sudo ./install.sh --with-chartmuseum
```


## 6. UI & Docker Login 확인

![harbor-1][harbor-1]

[harbor-1]:./images/harbor.PNG
