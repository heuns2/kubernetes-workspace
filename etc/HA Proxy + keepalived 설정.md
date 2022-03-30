# HA Proxy + keepalived 설정

## 테스트 환경 버전

- Centos v7.9
- HA Proxy v2.5.5
- Keepalived v2.2.4
- K8S Nginx Ingress, Master Node를 HA Proxy + keepalived로 설정

## 1. HA Proxy Install

- HA Proxy Package 압축 해제

```
$ tar xvf haproxy-2.5.5.tar.gz
$ cd haproxy-2.5.5
```

- HA Proxy Dependency 설치

```
$ sudo yum install gcc openssl openssl-devel pcre-static pcre-devel systemd-devel
```

- Make Install HA Proxy

```
# Target 설정
$ make TARGET=linux-glibc USE_OPENSSL=1 USE_PCRE=1 USE_ZLIB=1 USE_SYSTEMD=1

# Install
$ make install
```

- HA Proxy 버전 확인

```
$ haproxy -v
HAProxy version 2.5.5-384c5c5 2022/03/14 - https://haproxy.org/
Status: stable branch - will stop receiving fixes around Q1 2023.
Known bugs: http://www.haproxy.org/bugs/bugs-2.5.5.html
Running on: Linux 3.10.0-1127.19.1.el7.x86_64 #1 SMP Tue Aug 25 17:23:54 UTC 2020 x86_64
```

- HA Proxy 서비스 파일 등록

```

# 아래 내용을 파일에 설정
$ cat /etc/systemd/system/haproxy.service

[Unit]
Description=HAProxy Load Balancer
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=-/etc/default/haproxy
EnvironmentFile=-/etc/sysconfig/haproxy
Environment="CONFIG=/etc/haproxy/haproxy.cfg" "PIDFILE=/run/haproxy.pid" "EXTRAOPTS=-S /run/haproxy-master.sock"
ExecStart=/usr/local/sbin/haproxy -Ws -f $CONFIG -p $PIDFILE $EXTRAOPTS
ExecReload=/usr/local/sbin/haproxy -Ws -f $CONFIG -c -q $EXTRAOPTS
ExecReload=/bin/kill -USR2 $MAINPID
KillMode=mixed
Restart=always
SuccessExitStatus=143
Type=notify

# The following lines leverage SystemD's sandboxing options to provide
# defense in depth protection at the expense of restricting some flexibility
# in your setup (e.g. placement of your configuration files) or possibly
# reduced performance. See systemd.service(5) and systemd.exec(5) for further
# information.

# NoNewPrivileges=true
# ProtectHome=true
# If you want to use 'ProtectSystem=strict' you should whitelist the PIDFILE,
# any state files and any other files written using 'ReadWritePaths' or
# 'RuntimeDirectory'.
# ProtectSystem=true
# ProtectKernelTunables=true
# ProtectKernelModules=true
# ProtectControlGroups=true
# If your SystemD version supports them, you can add: @reboot, @swap, @sync
# SystemCallFilter=~@cpu-emulation @keyring @module @obsolete @raw-io

[Install]
WantedBy=multi-user.target
```

- HA Proxy 관련 디렉토리 생성

```
$ sudo mkdir -p /etc/haproxy
$ sudo mkdir -p /var/log/haproxy
``` 

- HA Proxy Config 파일 생성

```
global
  daemon
  log 127.0.0.1 local0
  log 127.0.0.1 local1 notice
  maxconn 20000

defaults
  mode                    http
  log                     global
  option                  httplog
  option                  dontlognull
  option http-server-close
  option forwardfor       except 127.0.0.0/8
  option                  redispatch
  retries                 3
  timeout http-request    10s
  timeout queue           1m
  timeout connect         10s
  timeout client          1m
  timeout server          1m
  timeout http-keep-alive 10s
  timeout check           10s
  maxconn                 20000


listen stats
  bind 127.0.0.1:9999
  balance
  mode http
  stats enable

#---------------------------------------------------------------------
# k8s
#---------------------------------------------------------------------
listen k8s-https
  balance  roundrobin
  bind :443
  log global
  mode tcp
  option tcplog
  server router 10.250.194.64:31590 check

listen k8s-http
  balance  roundrobin
  bind :80
  log global
  mode tcp
  option tcplog
  server router 10.250.194.64:32192 check

listen k8s-master
  balance  roundrobin
  bind :6443
  log global
  mode tcp
  option tcplog
  server master1 10.250.205.112:6443 check
  server master2 10.250.199.224:6443 check
  server master3 10.250.196.143:6443 check
```

- 서비스 실행 & 등록

```
$ systemctl daemon-reload
$ systemctl restart haproxy
$ systemctl enable haproxy
```

- LOG 설정

```
$ cat /etc/rsyslog.d/haproxy.conf
$ModLoad imudp
$UDPServerRun 514
$template Haproxy, "%msg%\n"
local0.=info -/var/log/haproxy/haproxy.log;Haproxy
local0.notice -/var/log/haproxy/haproxy-status.log;Haproxy

# rsyslog 재 실행
$ service rsyslog restart
```

## 2. keepalived Install

- 의존성 Package 설치

```
$ yum -y install libnl3-devel ipset-devel iptables-devel
```

- 압축 해제 및 Build & Install

```
$ tar xvf keepalived-2.2.4.tar.gz
$ cd keepalived-2.2.4

$ ./configure
$ make
$ make install

# 버전 확인
$ keepalived -v
Keepalived v2.2.4 (08/21,2021)

Copyright(C) 2001-2021 Alexandre Cassen, <acassen@gmail.com>
```

```
echo 'net.ipv4.ip_nonlocal_bind=1' >> /etc/sysctl.conf
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sudo sysctl -p
```

- 설정 전 확인

```
# Master
$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 06:0a:34:1c:69:97 brd ff:ff:ff:ff:ff:ff
    inet 10.250.226.172/20 brd 10.250.239.255 scope global dynamic eth0
       valid_lft 3404sec preferred_lft 3404sec
    inet6 fe80::40a:34ff:fe1c:6997/64 scope link
       valid_lft forever preferred_lft forever

# Backup
$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc mq state UP group default qlen 1000
    link/ether 06:9d:05:87:25:6f brd ff:ff:ff:ff:ff:ff
    inet 10.250.224.79/20 brd 10.250.239.255 scope global dynamic eth0
       valid_lft 2983sec preferred_lft 2983sec
    inet6 fe80::49d:5ff:fe87:256f/64 scope link
       valid_lft forever preferred_lft forever
```


- VIP 생성

```
# Master Node에서 실행
$ sudo ifconfig eth0:0 10.250.226.230 netmask 255.255.255.0
# Backup Node에서 실행
$ sudo ifconfig eth0:0 10.250.226.230 netmask 255.255.255.0
```

- Keepalived 설정 변경

```
# 디렉토리 생성
$ sudo mkdir -p /etc/keepalived

# Master Node에서 설정
$ vi /etc/keepalived/keepalived.conf

vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 200
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.250.226.230/24
    }
}

# Backup Node에서 설정
$ vi /etc/keepalived/keepalived.conf
vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.250.226.230/24
    }
}

# 서비스 실행 
systemctl enable keepalived
systemctl restart keepalived
```



## 3. keepalived  확인


```
$ ping 10.250.226.230

# Master Node Shutdown

# Master Node Start

# Backup Node Shutdown

# Backup Node Start
```
