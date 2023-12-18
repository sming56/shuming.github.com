#内核代码编译

参看https://km.sankuai.com/page/1271857132

##内核编译config文件建议选项
```
在.config文件中添加
CONFIG_KCOV=y
CONFIG_DEBUG_INFO=y
CONFIG_KASAN=y
CONFIG_KASAN_INLINE=y
CONFIG_CONFIGFS_FS=y
CONFIG_SECURITYFS=y
CONFIG_REFCOUNT_FULL=y <---我建议加入

//针对美团内核的修改
CONFIG_BLK_DEV_SD=y
CONFIG_ATA=y
CONFIG_ATA_PIIX=y
CONFIG_EXT4_FS=y
CONFIG_E1000=y
CONFIG_BINFMT_MISC=y
```

其他可选配置见：https://github.com/google/syzkaller/blob/master/docs/linux/kernel_configs.md

#找一个服务器制作镜像，比如1933
```
wget https://raw.githubusercontent.com/google/syzkaller/master/tools/create-image.sh -O create-image.sh
chmod +x create-image.sh
./create-image.sh

[shuming02@xr-hulk-k8s-node1933 image]$ ls
bullseye.id_rsa  bullseye.id_rsa.pub  bullseye.img  chroot  create-image.sh 
[shuming02@xr-hulk-k8s-node1933 image]$ 
[shuming02@xr-hulk-k8s-node1933 image]$ pwd
/work/shuming02/image
[shuming02@xr-hulk-k8s-node1933 image]$ 

```
#找一个DEV环境开始setup syzkaller运行环境

```
git clone https://github.com/google/syzkaller
make
[root@hh-hulk-k8s-ep-dev11 syzkaller]# make
Makefile:32: run command via tools/syz-env for best compatibility, see:
Makefile:33: https://github.com/google/syzkaller/blob/master/docs/contributing.md#using-syz-env
go list -f '{{.Stale}}' ./sys/syz-sysgen | grep -q false || go install ./sys/syz-sysgen
make .descriptions
bin/syz-sysgen
touch .descriptions
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" -o ./bin/syz-manager github.com/google/syzkaller/syz-manager
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" -o ./bin/syz-runtest github.com/google/syzkaller/tools/syz-runtest
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" -o ./bin/syz-repro github.com/google/syzkaller/tools/syz-repro
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" -o ./bin/syz-mutate github.com/google/syzkaller/tools/syz-mutate
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" -o ./bin/syz-prog2c github.com/google/syzkaller/tools/syz-prog2c
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" -o ./bin/syz-db github.com/google/syzkaller/tools/syz-db
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" -o ./bin/syz-upgrade github.com/google/syzkaller/tools/syz-upgrade
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" "-tags=syz_target syz_os_linux syz_arch_amd64 " -o ./bin/linux_amd64/syz-fuzzer github.com/google/syzkaller/syz-fuzzer
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" "-tags=syz_target syz_os_linux syz_arch_amd64 " -o ./bin/linux_amd64/syz-execprog github.com/google/syzkaller/tools/syz-execprog
GOOS=linux GOARCH=amd64 go build "-ldflags=-s -w -X github.com/google/syzkaller/prog.GitRevision=f819d6f7cb99737851dcaaa51f11190138fd48d5 -X 'github.com/google/syzkaller/prog.gitRevisionDate=20231129-151340'" "-tags=syz_target syz_os_linux syz_arch_amd64 " -o ./bin/linux_amd64/syz-stress github.com/google/syzkaller/tools/syz-stress
mkdir -p ./bin/linux_amd64
gcc -o ./bin/linux_amd64/syz-executor executor/executor.cc \
	-m64 -O2 -pthread -Wall -Werror -Wparentheses -Wframe-larger-than=16384 -Wno-stringop-overflow -Wno-array-bounds -Wno-format-overflow -Wno-unused-but-set-variable -Wno-unused-command-line-argument  -DGOOS_linux=1 -DGOARCH_amd64=1 \
	-DHOSTGOOS_linux=1 -DGIT_REVISION=\"f819d6f7cb99737851dcaaa51f11190138fd48d5\"
[root@hh-hulk-k8s-ep-dev11 syzkaller]# 

```

#启动syzkaller

##配置文件例子，详细解释请看：https://github.com/google/syzkaller/blob/master/pkg/mgrconfig/config.go

```
[root@hh-hulk-k8s-ep-dev11 bin]# cat my.cfg 
{
	"target": "linux/amd64",
	"http": "10.216.73.37:80", 《---当前服务器的IP地址，注意需要在avata里申请网络白名单允许工区访问这台服务器网络端口
	"workdir": "/home/shuming02/syzkaller/bin",
	"kernel_obj": "/opt/shuming02", <---找/opt/shuming02/vmlinux
	"image": "/opt/images/image/bullseye.img", <---上面制作好的镜像目录里的文件
	"sshkey": "/opt/images/image/bullseye.id_rsa", <---上面制作好的镜像目录里的文件
	"syzkaller": "/home/shuming02/syzkaller",
	"disable_syscalls": ["keyctl", "add_key", "request_key"],
	"procs": 8,
	"type": "qemu",
	"cover_filter": {"files": ["^net/ipv4/inet_connection_sock.c", "^net/ipv4/inet_hashtables.c"]},
	"vm": {
		"count": 4, 《--制定测试的VM数量
		"kernel": "/opt/shuming02/arch/x86/boot/bzImage",
		"cmdline": "net.ifnames=0", 《---这一行必须加，否者syzkaller ssh不上VM，也可以编译内核的时候编死在里面
		"cpu": 4,
		"mem": 4096
	}
}
[root@hh-hulk-k8s-ep-dev11 bin]# 
nohup ./syz-manager -config my.cfg & 《---注意，这里如果加了-debug选项，syzkaller最多只起一个VM

```
#在自己的工作机上观察运行结果

启动浏览器，输入http://http://10.216.73.37/

```
内核

1）更新go版本 wget https://go.dev/dl/go1.20.12.linux-amd64.tar.gz

2) 下载syzkaller

  3） export GOROOT=<your latest go dir>

4) cd syzkaller_dir and make

5) cd /usr/bin && ln /usr/libexec/qemu-kvm  -s qemu-system-x86_64

```
##如何用ssh访问正在测试中的VM

```
 qemu-system-x86_64 -m 2G -smp 2 -kernel /opt/shuming02/arch/x86/boot/bzImage -append "console=ttyS0 root=/dev/sda earlyprintmes=0" -drive file=/opt/images/image/bullseye.img,format=raw -net user,host=10.0.2.10,hostfwd=tcp:127.0.0.1:10021-:22 -net nic,model=e1000 -enable-kvm -nographic -pidfile vm.pid 2>&1 | tee vm.log


ssh -i /opt/images/image/bullseye.id_rsa -p 10021 -o "StrictHostKeyChecking no" root@localhost

```

#如何重现crash

```
https://android.googlesource.com/platform/external/syzkaller/+/HEAD/docs/reproducing_crashes.md

方法一）
./syz-repro -config my.cfg crashes/66735f48d4d59adea6eb52977fe128ca151e4989/repro.prog 
方法二）
需要自己创建测试VM然后把相关文件cp进测试VM
[root@hh-hulk-k8s-ep-dev11 ./bin/linux_amd64]# ./syz-execprog -executor=./syz-executor -repeat=0 -procs=16 -cover=0 ../../bin/crashes/66735f48d4d59adea6eb52977fe128ca151e4989/repro.prog 

```
##如何手动启动qemu虚拟机

手动启动qemu虚拟机

```
 /usr/local/bin/qemu-system-x86_64 -m 4096 -smp 4 -chardev socket,id=SOCKSYZ,server=on,wait=off,host=localhost,port=59425 -mon chardev=SOCKSYZ,mode=control -display none -serial stdio -no-reboot -name VM-6 -device virtio-rng-pci -enable-kvm -cpu host,migratable=off -device e1000,netdev=net0 -netdev user,id=net0,restrict=on,hostfwd=tcp:127.0.0.1:60149-:22 -hda /opt/images/bi-image/bullseye.img -snapshot -kernel /opt/shuming02/arch/x86/boot/bzImage -append "root=/dev/sda console=ttyS0 net.ifnames=0"
 // 注意  -append 后的双引号一定要
 // 如果需要每次运行的结果都持久化入镜像文件，请去掉-snapshot参数，改成”-hda /opt/images/bi-image/bullseye.img -snapshot“
 

```
##如何把宿主机上的文件cp到qemu虚拟机

```
scp -i /opt/images/image/bullseye.id_rsa -P 60149 -r /home/shuming02/syzkaller root@127.0.0.1:/root

```
##如何扩大虚拟机的root disk

```
//宿主机上扩大qemu img大小
[root@hh-hulk-k8s-ep-dev11]/usr/local/bin/qemu-img resize bullseye.img 30G
[root@hh-hulk-k8s-ep-dev11 bi-image]# qemu-img info bullseye.img
image: bullseye.img
file format: raw
virtual size: 30G (32212254720 bytes)
disk size: 2.0G

//启动VM后，root disk仍然是2G
root@syzkaller:~# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       2.0G  673M  1.2G  37% /
devtmpfs        1.6G     0  1.6G   0% /dev
tmpfs           1.6G     0  1.6G   0% /dev/shm
tmpfs           623M  180K  623M   1% /run
tmpfs           5.0M     0  5.0M   0% /run/lock
//运行resize2fs
root@syzkaller:~# resize2fs /dev/sda 
resize2fs 1.46.2 (28-Feb-2021)
Filesystem at /dev/sda is mounted on /; on-line resizing required
old_desc_bloc[   48.570976] EXT4-fs (sda): resizing filesystem from 524288 to 7864320 blocks
ks = 1, new_desc_blocks = 2
[   48.583560] EXT4-fs (sda): resized filesystem to 7864320
The filesystem on /dev/sda is now 7864320 (4k) blocks long.
//root disk已经是30G了
root@syzkaller:~# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/root        30G  675M   28G   3% /
devtmpfs        1.6G     0  1.6G   0% /dev
tmpfs           1.6G     0  1.6G   0% /dev/shm
tmpfs           623M  180K  623M   1% /run
tmpfs           5.0M     0  5.0M   0% /run/lock
root@syzkaller:~# 

```


