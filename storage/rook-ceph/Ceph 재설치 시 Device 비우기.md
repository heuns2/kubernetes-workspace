```
node1 : sda

lsblk -f

# ndoe1  sda device를 예시

yum install gdisk -y

sgdisk --zap-all "/dev/sda"
dd if=/dev/zero of="/dev/sda" bs=1M count=100 oflag=direct,dsync
partprobe /dev/sda


rm -rf /dev/ceph-*
rm -rf /dev/mapper/ceph--*
rm -rf /var/lib/rook
```
