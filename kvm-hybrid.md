## 混合部署概念

```
基于KVM的虚拟化能力，把GPOS和RTOS部署在同一台嵌入式宿主中，旣保证rtos的实时性，也可以让GPOS共享硬件资源
```

## 机器配置
### i5 8265u 4 core, 32G内存, 128G flash
### host os unbuntu 24.04

## Linux host 配置
```
1) 修改内核(/etc/default/grub)启动参数隔离一个CPU 3给RTOS
rcu_nocbs=3 nohz_full=3 isolcpus=3 irqaffinity=0-2 audit=0 watchdog=0 skew_tick=1
2) 打开iommu, 为pci设备passthrough给rtos作准备
intel_iommu=on iommu=pt
3) 执行update-grub2后重启host os
```

## 从host os选一个设备passthrough给rtos
### 假设选定一个设备intel-lpss
```
lspci -vnn

00:15.0 Serial bus controller [0c80]: Intel Corporation Cannon Point-LP Serial IO I2C Controller #0 [8086:9de8] (rev 30)
	DeviceName: Onboard - Other
	Subsystem: Intel Corporation Cannon Point-LP Serial IO I2C Controller [8086:7270]
	Flags: bus master, fast devsel, latency 0, IRQ 16, IOMMU group 4
	Memory at a1519000 (64-bit, non-prefetchable) [size=4K]
	Capabilities: <access denied>
	Kernel driver in use: intel-lpss
	Kernel modules: intel_lpss_pci

```
### 把该设备从host设备树解绑
```
test@kvm-server:~/vms$ cat /sys/bus/pci/devices/0000\:00\:15.0/modalias 
pci:v00008086d00009DE8sv00008086sd00007270bc0Csc80i00
test@kvm-server:~/vms$
test@kvm-server:~/vms$ cat /sys/bus/pci/devices/0000\:00\:15.0/modalias 
pci:v00008086d00009DE8sv00008086sd00007270bc0Csc80i00


test@kvm-server:~/vms$ sudo modprobe vfio-pci

root@kvm-server:~# echo '0000:00:15.0' > /sys/bus/pci/drivers/intel-lpss/unbind 
```
### 设备绑到vfio-pci
echo '0000:00:15.0' > /sys/bus/pci/drivers/vfio-pci/bind

## 启动kvm 虚拟机并把设备透传给它
```
root@kvm-server:/home/test/vms# mkdir -p /etc/qemu/bridge.conf //这部是绕过安全检查, 见文件内容
est@kvm-server:~$ cat /etc/qemu/bridge.conf
allow virbr0
allow all
test@kvm-server:~

root@kvm-server:/home/test/vms# cat ./vm.sh

taskset -c 3 qemu-system-x86_64 -smp 1 -m 4096 -enable-kvm ubuntu.img  -netdev bridge,id=ming-u1,br=virbr0 -device virtio-net-pci,netdev=ming-u1,id=virtio-net1 -vnc :1 -device vfio-pci,host=00:15.0 -daemonize
//注意这里是且借用了libvirtd创建的virtbr0 bridge
//qemu会为guest os拉起一个vnc server， qemu参数 -vnc :1对应的是vnc 端口号 5901 ，所以用vnc客户端连接“主机IP + 5901端口”就可以看到guest os的console输出
test@kvm-server:~/vms$ sudo ./vm.sh 
[sudo] password for test: 
qemu-system-x86_64: warning: host doesn't support requested feature: CPUID.80000001H:ECX.svm [bit 2]
qemu-system-x86_64: vfio: Cannot reset device 0000:00:15.0, no available reset mechanism.
qemu-system-x86_64: vfio: Cannot reset device 0000:00:15.0, no available reset mechanism.

test@kvm-guest:~$ lspci // rtos中可以看到passthrough 设备
00:00.0 Host bridge: Intel Corporation 440FX - 82441FX PMC [Natoma] (rev 02)
00:01.0 ISA bridge: Intel Corporation 82371SB PIIX3 ISA [Natoma/Triton II]
00:01.1 IDE interface: Intel Corporation 82371SB PIIX3 IDE [Natoma/Triton II]
00:01.3 Bridge: Intel Corporation 82371AB/EB/MB PIIX4 ACPI (rev 03)
00:02.0 VGA compatible controller: Device 1234:1111 (rev 02)
00:03.0 Ethernet controller: Red Hat, Inc. Virtio network device
00:04.0 Serial bus controller: Intel Corporation Cannon Point-LP Serial IO I2C Controller #0 (rev 30) <---passthrough
test@kvm-guest:~$ 
```
## rtos和gpos通讯
```
建议就用network socket，因为是本机基于virti-net的网络驱动，性能很强。
```
