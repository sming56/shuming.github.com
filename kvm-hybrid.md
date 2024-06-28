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
2) 打开iommu, 为pci设别passthrough给rtos作准备
intel_iommu=on iommu=pt
3) 执行update-grub2后重启host os
```

## 从host os选一个设备passthrough给rtos


