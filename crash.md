#crash工具用法

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

##Redhat crash如何找到引发 D进程得根因
###如何找到所有进程状态

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
##参看文献：
https://access.redhat.com/solutions/3538691



