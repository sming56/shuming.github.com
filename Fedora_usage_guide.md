## FC39上如何安装debug kernel
```
dnf debuginfo-install kernel //Fedora 39上安装 debug kernel文件
[root@localhost lib]# dnf debuginfo-install kernel
enabling fedora-debuginfo repository
enabling fedora-cisco-openh264-debuginfo repository
enabling updates-debuginfo repository
Last metadata expiration check: 0:03:48 ago on Tue 09 Jan 2024 06:54:40 AM UTC.
Could not find debugsource package for the following available packages: kernel-6.6.9-200.fc39
Dependencies resolved.
=====================================================================================================================================
 Package                                     Architecture        Version                        Repository                      Size
=====================================================================================================================================
Installing:
 kernel-debuginfo                            x86_64              6.6.9-200.fc39                 updates-debuginfo              846 M
Installing dependencies:
 kernel-debuginfo-common-x86_64              x86_64              6.6.9-200.fc39                 updates-debuginfo               87 M

Transaction Summary
=====================================================================================================================================
Install  2 Packages

Total size: 933 M
Total download size: 846 M
Installed size: 3.8 G
Is this ok [y/N]: y
Downloading Packages:
[SKIPPED] kernel-debuginfo-common-x86_64-6.6.9-200.fc39.x86_64.rpm: Already downloaded                                              
(2/2): kernel-debuginfo-6.6.9-200.fc39.x86_64.r 26% [============                                  ] 366 kB/s | 247 MB     31:59 ETA
```
## brtfs使用方式
```
[root@localhost ~]#  btrfs filesystem show /
Label: 'fedora'  uuid: 2f1b4fb2-54ec-4124-a3b4-1776614e5e4c
	Total devices 1 FS bytes used 2.77GiB
	devid    1 size 3.92GiB used 3.77GiB path /dev/sda5

[root@localhost ~]# 
[root@localhost ~]# btrfs device add /dev/sda6 / <---确保/dev/sda6是干净的分区，无lvm标志
Performing full device TRIM /dev/sda6 (10.00GiB) ...
[root@localhost ~]# 
[root@localhost ~]# btrfs filesystem resize max /
Resize device id 1 (/dev/sda5) from 3.92GiB to max
[root@localhost ~]# 
```
## 如何更改 Fedora linux kernel boot 参数
```
编辑/etc/default/grub文件
GRUB_TIMEOUT=1
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0 no_timer_check net.ifnames=0 console=tty1 console=ttyS0,115200n8 cgroup.memory=nokmem" <--加了cgroup.memory=nokmem
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
然后运行grub2-mkconfig
```
## 如何手工创建lvm分区，并mount到容器中
```
root@localhost ~]# pvcreate /dev/sda7 
  Physical volume "/dev/sda7" successfully created.
[root@localhost ~]# vgcreate dockervg /dev/sda7
  Volume group "dockervg" successfully created
[root@localhost ~]# lvcreate -L 9.9G -n lvmming dockervg
  Rounding up size to full physical extent 9.90 GiB
  Logical volume "lvmming" created.
[root@localhost ~]# 
[root@localhost ~]# mkfs.ex
mkfs.exfat  mkfs.ext2   mkfs.ext3   mkfs.ext4   
[root@localhost ~]# mkfs.ext4 /dev/dockervg/lvmming 
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 2595840 4k blocks and 648960 inodes
Filesystem UUID: 9b986a2d-05aa-497c-abb2-82c856a39a6c
Superblock backups stored on blocks: 
	32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done 

[root@localhost ~]# 
[root@localhost /]# mount /dev/dockervg/lvmming /ming
[root@localhost /]# docker run -itd --name ming --memory 8G -v /ming:/ming centos:7
39f6c345860eb104f8ba41a302062755225e9e818a3d9e6d69dd3e59cab5f8df

//setenforce 0 为了避免容器里没有权限访问该目录，关掉selinuxj检查
```


