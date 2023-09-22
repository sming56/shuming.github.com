#!/bin/bash
# 这个脚本会导致磁盘丢数据，请谨慎使用！！！
# 另外确认/dev/sd{}. /dev/df{}. /dev/vd{}是
# 正确的目标盘
set -x
PATH=/sbin:/bin:/usr/sbin:/usr/bin

[ -f /root/.hulk_initialized ] && exit 0

#确保docker没有启动
systemctl stop docker &>/dev/null
sleep 3

#umoun分区
umount /var/lib/docker/containers &>/dev/null
umount /var/lib/docker/devicemapper &>/dev/null

#清理lvm
dmsetup remove_all -f
vgreduce --removemissing --force dockervg
vgreduce --removemissing --force volumevg
vgremove -y dockervg
vgremove -y volumevg
pvremove -y `ls -1 /dev/sd{c..e}{1..2} 2>/dev/null | xargs`

#磁盘分区,无论多少块磁盘，第一个分区加起来1T(线下2T)，避免出错: 容量较少的磁盘对半分
DM_POOL_SIZE=1024
if [[ $(hostname)  =~ .*hulk-k8s-ep.* ]];then
    DM_POOL_SIZE=2048
fi

num_disks=`ls -1 /dev/sd{c..e} 2>/dev/null | wc -l`
part_size=$(( DM_POOL_SIZE / num_disks  + 1))

for disk in `ls -1 /dev/sd{c..e} 2>/dev/null`
do
    total_disk_bytes=`blockdev --getsize64 $disk`
    disk_size_gb=$((total_disk_bytes / 1000 / 1000 / 1000))
    if [ "$disk_size_gb" -gt "$((part_size * 2))" ];then
        parted -s $disk mklabel gpt mkpart dockervg 0% ${part_size}G mkpart volumevg ${part_size}G 100%
    else
        parted -s $disk mklabel gpt mkpart dockervg 0% 50% mkpart volumevg 50% 100%
    fi
done

#重新配置lvm
pvcreate -y `ls -1 /dev/sd{c..e}{1..2} 2>/dev/null | xargs `
vgcreate dockervg -y `ls -1 /dev/sd{c..e}1 2>/dev/null | xargs `
vgcreate volumevg -y `ls -1 /dev/sd{c..e}2 2>/dev/null | xargs `

#创建docker使用的dm-pool
#https://docs.docker.com/storage/storagedriver/device-mapper-driver/#configure-direct-lvm-mode-for-production
lvcreate -y --wipesignatures y  -n thinpoolmeta dockervg -l 1%VG
lvcreate -y --wipesignatures y  -n thinpool dockervg -l 95%VG
lvconvert -y --zero n -c 512K --thinpool dockervg/thinpool --poolmetadata dockervg/thinpoolmeta
lvchange --metadataprofile docker-thinpool dockervg/thinpool
lvs -o+seg_monitor

#重新创建dm-pool后需要删除docker目录才能正常启动
rm -rf /var/lib/docker

#启动docker
systemctl enable docker
systemctl start docker

#确保service目录sankuai可写，不用等待puppet同步就能使用puls发布
mkdir -p /service
chown sankuai /service

#避免下次开机再次执行
touch /root/.hulk_initialized
