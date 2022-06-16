```
apiVersion: v1
baseDomain: leedh.xxx
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    aws:
      rootVolume:
        iops: 2000
        size: 100
        type: gp2 
      type: t2.medium
      zones:
      - ap-northeast-1c
  replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    aws:
      rootVolume:
        iops: 2000
        size: 50
        type: gp2 
      type: t2.xlarge
      zones:
      - ap-northeast-1c
  replicas: 3
metadata:
  creationTimestamp: null
  name: oc-leedh
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.3.0/24
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  aws:
    region: ap-northeast-1
    subnets:
    - tas-service-subnet

publish: External
pullSecret: '{"auths":{"cloud.openshift.com":{"auth":"xxxxx"}}}'
sshKey: |+
  ssh-rsa xxxxxx
```
