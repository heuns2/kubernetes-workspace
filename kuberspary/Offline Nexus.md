admin / 43364587-e176-496b-bd67-5445022be09e

./rancher-save-images.sh --image-list ./images.list

./docker-push.sh --image-list ./images.list --registry 13.114.172.113:5000

docker login http://13.114.172.113:5000


apt-get install ipvsadm ipset python3-apt apt-transport-https software-properties-common \
conntrack apparmor libseccomp2 openssl curl rsync socat unzip e2fsprogs xfsprogs ebtables \
bash-completion \
--yes --reinstall --print-uris | awk -F "'" '{print $2}' | grep -v '^$' | sort -u > packages.urls


wget https://get.helm.sh/helm-v3.3.4-linux-amd64.tar.gz
wget https://github.com/containernetworking/plugins/releases/download/v0.9.0/cni-plugins-linux-amd64-v0.9.0.tgz
wget https://github.com/coreos/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-amd64.tar.gz
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.18.0/crictl-v1.18.0-linux-amd64.tar.gz
wget https://github.com/projectcalico/calicoctl/releases/download/v3.16.5/calicoctl-linux-amd64
wget https://storage.googleapis.com/kubernetes-release/release/v1.18.12/bin/linux/amd64/kubeadm
wget https://storage.googleapis.com/kubernetes-release/release/v1.18.12/bin/linux/amd64/kubectl
wget https://storage.googleapis.com/kubernetes-release/release/v1.18.12/bin/linux/amd64/kubelet

wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/a/apparmor/apparmor_2.13.3-7ubuntu5.1_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/b/bash-completion/bash-completion_2.10-1ubuntu1_all.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/c/conntrack-tools/conntrack_1.4.5-2_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/e/e2fsprogs/e2fsprogs_1.45.5-2ubuntu1.1_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/e/ebtables/ebtables_2.0.11-3build1_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/i/ipset/ipset_7.5-1ubuntu0.20.04.1_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/i/ipset/libipset13_7.5-1ubuntu0.20.04.1_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/i/ipvsadm/ipvsadm_1.31-1_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/libn/libnl3/libnl-3-200_3.4.0-1_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/libn/libnl3/libnl-genl-3-200_3.4.0-1_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/libs/libseccomp/libseccomp2_2.5.1-1ubuntu1~20.04.2_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/p/python-apt/python3-apt_2.0.0ubuntu0.20.04.7_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/r/rsync/rsync_3.1.3-8ubuntu0.3_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/s/socat/socat_1.7.3.3-2_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/s/software-properties/software-properties-common_0.99.9.8_all.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/u/unzip/unzip_6.0-25ubuntu1_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/main/x/xfsprogs/xfsprogs_5.3.0-1ubuntu2_amd64.deb
wget http://ap-northeast-1.ec2.archive.ubuntu.com/ubuntu/pool/universe/a/apt/apt-transport-https_2.0.9_all.deb

### apt 용 gpg key 생성 (RSA 3072)
gpg --gen-key
gpg --list-keys
### 위 list로 조회한 key fingerprint 의 공백을 제거한 문자가 아래 <gpg key fingerprint> 부분에 들어간다.
gpg --armor --output public.gpg.key --export 1E55D34CF69C2871FC65F1AEA05ABD2D5AC128DD
gpg --armor --output private.gpg.key --export-secret-key 1E55D34CF69C2871FC65F1AEA05ABD2D5AC128DD

private.gpg.key Key를 Nexus에 저장

