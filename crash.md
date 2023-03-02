# crash工具用法

## 如何用crash打印结构里的可变数组
```
crash> struct pid

struct pid {

    atomic_t count;

    unsigned int level;

    struct hlist_head tasks[4];

    struct callback_head rcu;

    struct upid numbers[1]; <—这个是可变数组，我们要打印struct pid结构里的members成员数组的第n个upid结构

}

SIZE: 72

crash> struct pid.numbers ffff9a87a73ce480 -o <---ffff9a87a73ce480是一个指向struct pid的地址

struct pid {

  [ffff9a87a73ce4b8] struct upid numbers[1]; <---ffff9a87a73ce4b8是numbers成员的地址

}

crash> px ((struct upid *)0xffff9a87a73ce4b8)[1] 《---打印numbers第二个成员

$4 = {

  nr = 0xcccccccc, 

  ns = 0xcccccccccccccccc

}

crash> px ((struct upid *)0xffff9a87a73ce4b8)[2] 《---打印numbers第三个成员

$6 = {

  nr = 0xcccccccc, 

  ns = 0xcccccccccccccccc

}

crash> 

## Redhat crash如何找到引发 D进程得根因
### 如何找到所有进程状态

代码块
crash> ps -S
  RU: 18
  IN: 756
  UN: 43
  ZO: 7
​
crash> foreach UN bt | awk '/#1 /{print $3,$5}' | sort | uniq -c | sort -nr
     39 rwsem_down_failed_common ffffffff8154d7d5
      4 schedule_timeout ffffffff8154b532
​
crash> foreach UN bt | awk '/#2 /{print $3,$5}' | sort | uniq -c | sort -nr
     37 rwsem_down_read_failed ffffffff8154d966
      4 io_schedule_timeout ffffffff8154a11f
      2 rwsem_down_write_failed ffffffff8154d933
```
###如何找到处于D进程的最老的几个进程，大概率是触发问题的地方
```
代码块
crash> foreach UN ps -m | tail
[ 3 13:06:10.433] [UN]  PID: 3156   TASK: ffff885f82042ab0  CPU: 6   COMMAND: "pidof"
[ 3 15:45:59.368] [UN]  PID: 12193  TASK: ffff88bfaad2cab0  CPU: 3   COMMAND: "pidof"
[ 4 13:04:51.415] [UN]  PID: 19050  TASK: ffff88bfaba04ab0  CPU: 2   COMMAND: "pidof"
[ 4 15:44:43.411] [UN]  PID: 27625  TASK: ffff885f7760aab0  CPU: 1   COMMAND: "pidof"
[ 4 17:15:49.212] [UN]  PID: 13080  TASK: ffff885f779a7520  CPU: 0   COMMAND: "ps"
[ 4 17:17:42.141] [UN]  PID: 12243  TASK: ffff88bfabbbe040  CPU: 0   COMMAND: "ps"
[ 4 18:02:06.500] [UN]  PID: 5645   TASK: ffff882f2df2e040  CPU: 11  COMMAND: "ps"
[ 4 19:19:46.360] [UN]  PID: 3030   TASK: ffff88bfab9c0040  CPU: 9   COMMAND: "processx"
[ 4 19:47:36.825] [UN]  PID: 7631   TASK: ffff885fa5b19520  CPU: 4   COMMAND: "pim"
[ 4 19:47:36.526] [UN]  PID: 25053  TASK: ffff885f776f2ab0  CPU: 5   COMMAND: "processx"
```
### 查看最老的那个进程
```
代码块
crash> set 25053
    PID: 25053
COMMAND: "processx"
   TASK: ffff885f776f2ab0  [THREAD_INFO: ffff885f6f6ec000]
    CPU: 5
  STATE: TASK_UNINTERRUPTIBLE 
​
crash> bt
PID: 25053  TASK: ffff885f776f2ab0  CPU: 5   COMMAND: "processx"
 #0 [ffff885f6f6efd28] schedule at ffffffff8154a640
 #1 [ffff885f6f6efe00] rwsem_down_failed_common at ffffffff8154d7d5
 #2 [ffff885f6f6efe60] rwsem_down_write_failed at ffffffff8154d933
 #3 [ffff885f6f6efea0] call_rwsem_down_write_failed at ffffffff812a85b3
 #4 [ffff885f6f6eff00] sys_mmap_pgoff at ffffffff8114fbab
 #5 [ffff885f6f6eff70] sys_mmap at ffffffff810124f9
 #6 [ffff885f6f6eff80] tracesys at ffffffff8100b2e8 (via system_call)
    RIP: 0000003e7d8e558a  RSP: 00007fff4d5ece38  RFLAGS: 00000202
    RAX: ffffffffffffffda  RBX: ffffffff8100b2e8  RCX: ffffffffffffffff
    RDX: 0000000000000003  RSI: 0000000000300000  RDI: 0000000000000000
    RBP: 00007fff4d5ece60   R8: 00000000ffffffff   R9: 0000000000000000
    R10: 0000000000000022  R11: 0000000000000202  R12: ffffffff810124f9
    R13: ffff885f6f6eff78  R14: 00002afd41060580  R15: 00000000ffffffff
    ORIG_RAX: 0000000000000009  CS: 0033  SS: 002b
​
290 SYSCALL_DEFINE6(mmap_pgoff, unsigned long, addr, unsigned long, len,
291                 unsigned long, prot, unsigned long, flags,
292                 unsigned long, fd, unsigned long, pgoff)
293 {
    ...
330         down_write(&current->mm->mmap_sem);
    ...
```
## 参看文献：
https://access.redhat.com/solutions/3538691

## 如何调试list corruption问题
```
KERNEL: /cores/retrace/repos/kernel/x86_64/usr/lib/debug/lib/modules/4.18.0-305.el8.x86_64/vmlinux
    DUMPFILE: /cores/retrace/tasks/140115919/crash/vmcore  [PARTIAL DUMP]
        CPUS: 4
        DATE: Wed Jun  2 15:57:36 GMT 2021
      UPTIME: 6 days, 14:36:17
LOAD AVERAGE: 0.00, 0.00, 0.00
       TASKS: 374
     RELEASE: 4.18.0-305.el8.x86_64
     VERSION: #1 SMP Thu Apr 29 08:54:30 EDT 2021
     MACHINE: x86_64  (2399 Mhz)
      MEMORY: 12 GB
       PANIC: "kernel BUG at lib/list_debug.c:50!"

        DMI_BIOS_VENDOR: Phoenix Technologies LTD
       DMI_BIOS_VERSION: 6.00
          DMI_BIOS_DATE: 12/12/2018

  x86_model_id = "Intel(R) Xeon(R) CPU E5-2680 v4 @ 2.40GHz
  microcode = 0x2006906,

[   13.097059] vmxnet3 0000:13:00.0 lan1: intr type 3, mode 0, 5 vectors allocated
[   13.097753] vmxnet3 0000:13:00.0 lan1: NIC Link is Up 10000 Mbps
[570928.662632] list_del corruption, ffff8b3c3b76b048->prev is LIST_POISON2 (dead000000000200)
[570928.662739] ------------[ cut here ]------------
[570928.662740] kernel BUG at lib/list_debug.c:50!
[570928.662773] invalid opcode: 0000 [#1] SMP PTI
[570928.662790] CPU: 2 PID: 756280 Comm: kworker/2:0 Kdump: loaded Not tainted 4.18.0-305.el8.x86_64 #1
[570928.662818] Hardware name: VMware, Inc. VMware Virtual Platform/440BX Desktop Reference Platform, BIOS 6.00 12/12/2018
[570928.662853] Workqueue: cgroup_destroy css_release_work_fn
[570928.662874] RIP: 0010:__list_del_entry_valid.cold.1+0x45/0x4c
[570928.662894] Code: e8 8a a5 cb ff 0f 0b 48 89 f2 48 89 fe 48 c7 c7 40 66 10 95 e8 76 a5 cb ff 0f 0b 48 89 fe 48 c7 c7 08 66 10 95 e8 65 a5 cb ff <0f> 0b 90 90 90 90 90 41 55 41 54 55 53 48 85 d2 74 5f 48 85 f6 74
[570928.662950] RSP: 0018:ffffa22203613e68 EFLAGS: 00010246
[570928.662969] RAX: 000000000000004e RBX: ffff8b3c3b76b090 RCX: 0000000000000000
[570928.662992] RDX: 0000000000000000 RSI: ffff8b3f33d167c8 RDI: ffff8b3f33d167c8
[570928.663014] RBP: ffffffff95826040 R08: 00000000000005b7 R09: 0000000000aaaaaa
[570928.663037] R10: 0000000000000000 R11: ffffa22202dff200 R12: ffff8b3c3b76b000
[570928.663059] R13: ffff8b3f2c0b0000 R14: ffff8b3dfe60d240 R15: ffff8b3c3b76b098
[570928.663082] FS:  0000000000000000(0000) GS:ffff8b3f33d00000(0000) knlGS:0000000000000000
[570928.663107] CS:  0010 DS: 0000 ES: 0000 CR0: 0000000080050033
[570928.663126] CR2: 00007f2a5bddc500 CR3: 00000001e1a10005 CR4: 00000000003706e0
[570928.663184] Call Trace:
[570928.663204]  css_release_work_fn+0x3f/0x240
[570928.663254]  process_one_work+0x1a7/0x360
[570928.663276]  worker_thread+0x30/0x390
[570928.663291]  ? create_worker+0x1a0/0x1a0
[570928.663305]  kthread+0x116/0x130
[570928.663326]  ? kthread_flush_work_fn+0x10/0x10
[570928.663344]  ret_from_fork+0x35/0x40
[570928.663361] Modules linked in: binfmt_misc nft_fib_inet nft_fib_ipv4 nft_fib_ipv6 nft_fib nft_reject_inet nf_reject_ipv4 nf_reject_ipv6 nft_reject nft_ct nf_tables_set nft_chain_nat nf_nat nf_conntrack nf_defrag_ipv6 nf_defrag_ipv4 ip_set nf_tables nfnetlink vsock_loopback vmw_vsock_virtio_transport_common vmw_vsock_vmci_transport vsock intel_rapl_msr intel_rapl_common sb_edac crct10dif_pclmul crc32_pclmul ghash_clmulni_intel rapl vmw_balloon joydev pcspkr i2c_piix4 vmw_vmci ip_tables xfs libcrc32c sr_mod cdrom ata_generic vmwgfx sd_mod t10_pi sg drm_kms_helper syscopyarea sysfillrect sysimgblt fb_sys_fops ttm drm crc32c_intel ata_piix ahci libahci serio_raw libata vmxnet3 vmw_pvscsi dm_mirror dm_region_hash dm_log dm_mod fuse

crash> list_head ffff8b3c3b76b048
struct list_head {
  next = 0xffff8b3efb312058, 
  prev = 0xdead000000000200
}

crash> bt
PID: 756280  TASK: ffff8b3f1fff17c0  CPU: 2   COMMAND: "kworker/2:0"
 #0 [ffffa22203613bf0] machine_kexec at ffffffff9406156e
 #1 [ffffa22203613c48] __crash_kexec at ffffffff9418f99d
 #2 [ffffa22203613d10] crash_kexec at ffffffff9419088d
 #3 [ffffa22203613d28] oops_end at ffffffff9402434d
 #4 [ffffa22203613d48] do_trap at ffffffff94020b13
 #5 [ffffa22203613d90] do_invalid_op at ffffffff94021476
 #6 [ffffa22203613db0] invalid_op at ffffffff94a00d64
    [exception RIP: __list_del_entry_valid.cold.1+69]
    RIP: ffffffff94491209  RSP: ffffa22203613e68  RFLAGS: 00010246
    RAX: 000000000000004e  RBX: ffff8b3c3b76b090  RCX: 0000000000000000
    RDX: 0000000000000000  RSI: ffff8b3f33d167c8  RDI: ffff8b3f33d167c8
    RBP: ffffffff95826040   R8: 00000000000005b7   R9: 0000000000aaaaaa
    R10: 0000000000000000  R11: ffffa22202dff200  R12: ffff8b3c3b76b000
    R13: ffff8b3f2c0b0000  R14: ffff8b3dfe60d240  R15: ffff8b3c3b76b098
    ORIG_RAX: ffffffffffffffff  CS: 0010  SS: 0018
 #7 [ffffa22203613e60] __list_del_entry_valid.cold.1 at ffffffff94491209
 #8 [ffffa22203613e68] css_release_work_fn at ffffffff94196b0f
 #9 [ffffa22203613e98] process_one_work at ffffffff940fe397
#10 [ffffa22203613ed8] worker_thread at ffffffff940fea60
#11 [ffffa22203613f10] kthread at ffffffff94104406
#12 [ffffa22203613f50] ret_from_fork at ffffffff94a00255

crash> dis -rl ffffffff94491209 | tail
0xffffffff944911e9 <__list_del_entry_valid.cold.1+37>:  mov    %rdi,%rsi
0xffffffff944911ec <__list_del_entry_valid.cold.1+40>:  mov    $0xffffffff95106640,%rdi
0xffffffff944911f3 <__list_del_entry_valid.cold.1+47>:  callq  0xffffffff9414b76e <printk>
/usr/src/debug/kernel-4.18.0-305.el8/linux-4.18.0-305.el8.x86_64/lib/list_debug.c: 51
0xffffffff944911f8 <__list_del_entry_valid.cold.1+52>:  ud2    
0xffffffff944911fa <__list_del_entry_valid.cold.1+54>:  mov    %rdi,%rsi
0xffffffff944911fd <__list_del_entry_valid.cold.1+57>:  mov    $0xffffffff95106608,%rdi
0xffffffff94491204 <__list_del_entry_valid.cold.1+64>:  callq  0xffffffff9414b76e <printk>
/usr/src/debug/kernel-4.18.0-305.el8/linux-4.18.0-305.el8.x86_64/lib/list_debug.c: 48
0xffffffff94491209 <__list_del_entry_valid.cold.1+69>:  ud2   

 38 bool __list_del_entry_valid(struct list_head *entry)
 39 {
 40         struct list_head *prev, *next;
 41 
 42         prev = entry->prev;
 43         next = entry->next;
 44 
 45         if (CHECK_DATA_CORRUPTION(next == LIST_POISON1,
 46                         "list_del corruption, %px->next is LIST_POISON1 (%px)\n",
 47                         entry, LIST_POISON1) ||
 48             CHECK_DATA_CORRUPTION(prev == LIST_POISON2,
 49                         "list_del corruption, %px->prev is LIST_POISON2 (%px)\n",
 50                         entry, LIST_POISON2) ||
 51             CHECK_DATA_CORRUPTION(prev->next != entry,
 52                         "list_del corruption. prev->next should be %px, but was %px\n",

crash> dis -rl ffffffff94196b0f | tail
/usr/src/debug/kernel-4.18.0-305.el8/linux-4.18.0-305.el8.x86_64/kernel/cgroup/cgroup.c: 4975
0xffffffff94196aee <css_release_work_fn+30>:    mov    $0xffffffff956b5f20,%rdi
0xffffffff94196af5 <css_release_work_fn+37>:    lea    -0x90(%rbx),%r12
0xffffffff94196afc <css_release_work_fn+44>:    callq  0xffffffff9494a400 <mutex_lock>
/usr/src/debug/kernel-4.18.0-305.el8/linux-4.18.0-305.el8.x86_64/kernel/cgroup/cgroup.c: 4977
0xffffffff94196b01 <css_release_work_fn+49>:    orl    $0x4,-0x14(%rbx)
/usr/src/debug/kernel-4.18.0-305.el8/linux-4.18.0-305.el8.x86_64/./include/linux/list.h: 131
0xffffffff94196b05 <css_release_work_fn+53>:    lea    0x48(%r12),%rdi
0xffffffff94196b0a <css_release_work_fn+58>:    callq  0xffffffff94491150 <__list_del_entry_valid>

4968 static void css_release_work_fn(struct work_struct *work)
4969 {
4970         struct cgroup_subsys_state *css =
4971                 container_of(work, struct cgroup_subsys_state, destroy_work);
4972         struct cgroup_subsys *ss = css->ss;
4973         struct cgroup *cgrp = css->cgroup;
4974 
4975         mutex_lock(&cgroup_mutex);
4976 
4977         css->flags |= CSS_RELEASED;
4978         list_del_rcu(&css->sibling);

crash> work_struct ffff8b3c3b76b090
struct work_struct {
  data = {
    counter = 128
  }, 
  entry = {
    next = 0xffff8b3c3b76b098, 
    prev = 0xffff8b3c3b76b098
  }, 
  func = 0xffffffff94196ad0, 
  rh_reserved1 = 0, 
  rh_reserved2 = 0, 
  rh_reserved3 = 0, 
  rh_reserved4 = 0
}

crash> cgroup_subsys_state.destroy_work -ox
struct cgroup_subsys_state {
   [0x90] struct work_struct destroy_work;
}

crash> px 0xffff8b3c3b76b090-0x90
$4 = 0xffff8b3c3b76b000

/usr/src/debug/kernel-4.18.0-305.el8/linux-4.18.0-305.el8.x86_64/kernel/cgroup/cgroup.c: 4973
    4973    struct cgroup *cgrp = css->cgroup;
0xffffffff94196ae7 <css_release_work_fn+23>:    mov    -0x90(%rdi),%r13

R13: ffff8b3f2c0b0000 // cgroup

crash> cgroup_subsys_state.cgroup 0xffff8b3c3b76b000
  cgroup = 0xffff8b3f2c0b0000

crash> cgroup_subsys_state 0xffff8b3c3b76b000 -x
struct cgroup_subsys_state {
  cgroup = 0xffff8b3f2c0b0000, 
  ss = 0xffffffff95826040, 
  refcnt = {
    count = {
      counter = 0x0
    }, 
    percpu_count_ptr = 0x3, 
    release = 0xffffffff94193db0, 
    confirm_switch = 0x0, 
    force_atomic = 0x0, 
    allow_reinit = 0x0, 
    rcu = {
      next = 0xffff8b3f2c0b0b90, 
      func = 0x0
    }
  }, 
  sibling = {
    next = 0xffff8b3efb312058, 
    prev = 0xdead000000000200 <<
  }, 
  children = {
    next = 0xffff8b3c3b76b058, 
    prev = 0xffff8b3c3b76b058
  }, 
  rstat_css_node = {
    next = 0xffff8b3c3b76b068, 
    prev = 0xffff8b3c3b76b068
  }, 
  id = 0x87, 
  flags = 0x14, 
  serial_nr = 0xc394b, 
  online_cnt = {
    counter = 0x0
  }, 
  destroy_work = {
    data = {
      counter = 0x80
    }, 
    entry = {
      next = 0xffff8b3c3b76b098, 
      prev = 0xffff8b3c3b76b098
    }, 
    func = 0xffffffff94196ad0, 
    rh_reserved1 = 0x0, 
    rh_reserved2 = 0x0, 
    rh_reserved3 = 0x0, 
    rh_reserved4 = 0x0
  }, 
  destroy_rwork = {
    work = {
      data = {
        counter = 0xfffffffe1
      }, 
      entry = {
        next = 0xffff8b3c3b76b0d8, 
        prev = 0xffff8b3c3b76b0d8
      }, 
      func = 0xffffffff9419b410, 
      rh_reserved1 = 0x0, 
      rh_reserved2 = 0x0, 
      rh_reserved3 = 0x0, 
      rh_reserved4 = 0x0
    }, 
    rcu = {
      next = 0xffff8b3d6bd46b10, 
      func = 0xffffffff940fe1c0
    }, 
    wq = 0xffff8b3d06325e00
  }, 
  parent = 0xffff8b3efb312000
}


crash> cgroup_subsys_state.flags -x 0xffff8b3c3b76b000
  flags = 0x14

 50 enum {           
 51         CSS_NO_REF      = (1 << 0), /* no reference counting for this css */
 52         CSS_ONLINE      = (1 << 1), /* between ->css_online() and ->css_offline() */
 53         CSS_RELEASED    = (1 << 2), /* refcnt reached zero, released */

crash> pd (1 << 2)
$5 = 4

crash> pd (0x14 && 0x04)
$6 = 1

it's dead for mapping.

crash> kmem 0xffff8b3c3b76b000
CACHE             OBJSIZE  ALLOCATED     TOTAL  SLABS  SSIZE  NAME
ffff8b3d07c028c0     4096        744       824    103    32k  kmalloc-4k
  SLAB              MEMORY            NODE  TOTAL  ALLOCATED  FREE
  ffffd16c40edda00  ffff8b3c3b768000     0      8          1     7
  FREE / [ALLOCATED]
  [ffff8b3c3b76b000]

      PAGE        PHYSICAL      MAPPING       INDEX CNT FLAGS
ffffd16c40eddac0  3b76b000 dead000000000400        0  0 fffffc0000000

crash> cgroup_subsys_state.cgroup 0xffff8b3c3b76b000
  cgroup = 0xffff8b3f2c0b0000

R13: ffff8b3f2c0b0000

crash> kmem ffff8b3f2c0b0000
CACHE             OBJSIZE  ALLOCATED     TOTAL  SLABS  SSIZE  NAME
ffff8b3d07c028c0     4096        744       824    103    32k  kmalloc-4k
  SLAB              MEMORY            NODE  TOTAL  ALLOCATED  FREE
  ffffd16c4cb02c00  ffff8b3f2c0b0000     0      8          7     1
  FREE / [ALLOCATED]
  [ffff8b3f2c0b0000]

      PAGE        PHYSICAL      MAPPING       INDEX CNT FLAGS
ffffd16c4cb02c00 32c0b0000 ffff8b3d07c028c0 ffff8b3f2c0b1000  1 17ffffc0008100 slab,head

crash> cgroup.kn 0xffff8b3f2c0b0000
  kn = 0xffff8b3dc0f8bc38

crash> kernfs_node.name 0xffff8b3dc0f8bc38
  name = 0xffff8b3f2e498300 "user-runtime-dir@1005.service"

crash> kernfs_node.name 0xffff8b3efb20d330
  name = 0xffff8b3f1f386dc0 "system-user\\x2druntime\\x2ddir.slice"

crash> cgroup_subsys_state.sibling ffff8b3f2c0b0000
  sibling = {
    next = 0xffff8b3efb311058, 
    prev = 0xffff8b3efb311058
  }

crash> cgroup_subsys_state.sibling ffff8b3f2c0b0000 -ox
struct cgroup_subsys_state {
  [ffff8b3f2c0b0048] struct list_head sibling;
}

crash> list -H ffff8b3f2c0b0048
ffff8b3efb311058

crash> kmem -i
                 PAGES        TOTAL      PERCENTAGE
    TOTAL MEM  3020862      11.5 GB         ----
         FREE    60625     236.8 MB    2% of TOTAL MEM
         USED  2960237      11.3 GB   97% of TOTAL MEM
       SHARED    96512       377 MB    3% of TOTAL MEM
      BUFFERS        1         4 KB    0% of TOTAL MEM
       CACHED  1559338       5.9 GB   51% of TOTAL MEM
         SLAB    23532      91.9 MB    0% of TOTAL MEM

   TOTAL HUGE        0            0         ----
    HUGE FREE        0            0    0% of TOTAL HUGE

   TOTAL SWAP   488447       1.9 GB         ----
    SWAP USED   112130       438 MB   22% of TOTAL SWAP
    SWAP FREE   376317       1.4 GB   77% of TOTAL SWAP

 COMMIT LIMIT  1998878       7.6 GB         ----
    COMMITTED  2011970       7.7 GB  100% of TOTAL LIMIT

======================================================================
           [ RSS usage ]          [ Process name ]
======================================================================
         4 GiB (   5087396 KiB)   mysqld
        36 MiB (     37428 KiB)   firewalld
        32 MiB (     33348 KiB)   beremote
        27 MiB (     27900 KiB)   tuned
        23 MiB (     23976 KiB)   polkitd
        18 MiB (     18584 KiB)   snmpd
        17 MiB (     18376 KiB)   NetworkManager
        15 MiB (     15944 KiB)   systemd-journal
        13 MiB (     14208 KiB)   systemd
        12 MiB (     12828 KiB)   vmtoolsd
======================================================================
Total memory usage from user-space = 5.12 GiB

crash> mod -t
no tainted modules
```

## 如何用crash搜进程栈上数据
```
crash> search -T ffff9a713c859a00 #搜active 进程栈 -t 包括不活跃进程栈
PID: 45927  TASK: ffff9a6af28a9ec0  CPU: 39  COMMAND: "rg"
ffffabeb605d3e48: ffff9a713c859a00 
ffffabeb605d3ea8: ffff9a713c859a00 
ffffabeb605d3ed8: ffff9a713c859a00 
```


