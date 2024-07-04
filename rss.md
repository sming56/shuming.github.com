## RFS 实现得两张表
```
RFS通过两张表来防止用户态进程迁移后，原CPU backlog队列堆积的未处理包和新CPU的backloh队列网络包乱序问题。
```
```
第一张表，rps_sock_flow_table 这张表是记录用户态程序收发同流最后一个网络包所用CPU，一般是用户态进程调用recvmsg ()和sendmsg()时顺便更新一下这张表。但是当用户态进程被调度到另外一个CPU上，老得CPU上对应得backlog队列可能残存着很多网络包未处理，此进程如果在新CPU开始收发包得话，可能会导致网络包乱序。所以引入了第二张表
```
```
第二张表rps_dev_flow_table 这张表用来存储网卡硬件所属得收队列。这张表每项填有cpu index和硬件往对应cpu backlog所收网络包个数，这张表也可以认为是内核记录所收收同流最后一个网络包backlog的CPU index。
```
```
正常情况下同一条流在两张表上对应的CPU index是一致得，这有利网络性能。但是当用户态进程被迁移之后，两边得CPU就不等了。当内核调用get_rps_cpu()函数决定是否更新当前CPU时会做如下判断
1）cpu同流backlog地head couner（存在backlog dequeue中） >= tail counter(存在rps_dev_flow_table[i], i对应得是网络流）

head counter + 未处理得网络包字节数总和 = tail counter，如果上述条件成立，说明没有未处理网络包了，可以更新cpu index了，新得cpu index就是进程新迁移到的CPU

2) 老CPU unset了

3）老cpu 下线了
```

