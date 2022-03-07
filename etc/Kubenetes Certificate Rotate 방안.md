# Kubenetes Certificate Rotate 방안

### Cert Rotate 전 확인
$ kubeadm alpha certs check-expiration
Command "check-expiration" is deprecated, please use the same command under "kubeadm certs"
[check-expiration] Reading configuration from the cluster...
[check-expiration] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
W0307 08:24:55.740353    1369 utils.go:69] The recommended value for "clusterDNS" in "KubeletConfiguration" is: [10.233.0.10]; the provided value is: [169.254.25.10]

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Jul 15, 2022 07:57 UTC   129d                                    no
apiserver                  Jul 15, 2022 08:08 UTC   129d            ca                      no
apiserver-kubelet-client   Jul 15, 2022 07:57 UTC   129d            ca                      no
controller-manager.conf    Jul 15, 2022 07:57 UTC   129d                                    no
front-proxy-client         Jul 15, 2022 07:57 UTC   129d            front-proxy-ca          no
scheduler.conf             Jul 15, 2022 07:57 UTC   129d                                    no

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Jul 13, 2031 07:57 UTC   9y              no
front-proxy-ca          Jul 13, 2031 07:57 UTC   9y              no

### Cert Renew 명령 실행
$ kubeadm certs renew all

### Cert Rotate 후 확인
$ kubeadm alpha certs check-expiration
Command "check-expiration" is deprecated, please use the same command under "kubeadm certs"
[check-expiration] Reading configuration from the cluster...
[check-expiration] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
W0307 08:50:22.972824   23058 utils.go:69] The recommended value for "clusterDNS" in "KubeletConfiguration" is: [10.233.0.10]; the provided value is: [169.254.25.10]

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Mar 07, 2023 08:25 UTC   364d                                    no
apiserver                  Mar 07, 2023 08:25 UTC   364d            ca                      no
apiserver-kubelet-client   Mar 07, 2023 08:25 UTC   364d            ca                      no
controller-manager.conf    Mar 07, 2023 08:25 UTC   364d                                    no
front-proxy-client         Mar 07, 2023 08:25 UTC   364d            front-proxy-ca          no
scheduler.conf             Mar 07, 2023 08:25 UTC   364d                                    no

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Jul 13, 2031 07:57 UTC   9y              no
front-proxy-ca          Jul 13, 2031 07:57 UTC   9y              no

### Static Pod 디렉토리 이동
$ cd /etc/kubernetes/manifests

### 임시 디렉토리 생성
$ mkdir cert

### 모든 Static Pod yaml 파일을 임시 작업 디렉토리(cert)로 이동
$ mv kube-* cert/

### 약 30초 경과 후 대기 후 다시 임시 작업 디렉토리(cert)로 Static Pod yaml들을 다시 이동
$ mv cert/* .

### 아래 명령어를 통하여 Static Pod의 Start 시간 확인 (모든 Static Pod 확인 필요)
$ kubectl -n kube-system describe pod  {STATIC-POD-NAME} | grep -i Started:
      Started:      Mon, 07 Mar 2022 08:42:13 +0000

### 전체 Pod Running 확인
$ kubectl get pods -A

### Container Ingress Request 확인
