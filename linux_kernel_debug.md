如何从内核地址得到源代码中的变量
安装kernel-debuginfo-3.10.0-862.xxx.el7.x86_64.rpm                kernel-debuginfo-common-x86_64-3.10.0-862.xxx.el7.x86_64.rpm  包

[root@host shuming02]# eu-addr2line -f -k 0xffffffff8a85d517

tcp_v4_rcv

net/ipv4/tcp_ipv4.c:1746

[root@host shuming02]
