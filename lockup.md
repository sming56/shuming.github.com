#lockup 分为soft lockup和hard lockup
##soft lockup
```
soft lockup定义为在某个特定CPU上连续不间断运行内核代码，用户态进程得不到调度，这个连续时间缺省为20秒
```
##hard lockup
```
hard lockup定义为在某个特定CPU上连续不间断关闭中断处理运行代码，中断得不到处理，这个连续时间缺省为10秒
```
##如何探测hard lockup
```
hrtimer会每隔一段时间向每个CPU发一个中断，NMI perf中断也会每隔一段时间(watchdog_thresh)向每个CPU发一个不可屏蔽中断，假设hrtimer时间间隔为t,
t=2*watchdog_thresh/5
watchdog_thresh缺省是10秒，所以一个watchdog_thresh大概能发3，4个hrtimer中断。
hrtimer中断负责启动watchdog任务，更新收到hrtimer个数，然后NMI perf中断会定期检查hrtimer个数首否更新，如果没有跟新就认为是hard lockup了
```
##NO_HZ_FULL对探测的影响
```
如果内核没有打开NO_HZ_FULL宏，每个CPU都会运行watchdog认为，但是如果配置了，就只有某些打扫卫生核会运行watchdog任务
```

