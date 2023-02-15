如何从内核地址得到源代码中的变量
安装kernel-debuginfo-3.10.0-862.xxx.el7.x86_64.rpm                kernel-debuginfo-common-x86_64-3.10.0-862.xxx.el7.x86_64.rpm  包

[root@host shuming02]# eu-addr2line -f -k 0xffffffff8a85d517

tcp_v4_rcv

net/ipv4/tcp_ipv4.c:1746

[root@host shuming02]

trace工具用法
yum install bcc-tools
export PATH=/usr/share/bcc/tools/:$PATH
trace 'p::shrink_active_list(unsigned long nr_to_scan,struct lruvec *lruvec,struct scan_control *sc,enum lru_list lru) "lru = %d", lru'

bpftrace工具
wget  http://kernel.sankuai.com/tools/zenghongyang/bpftrace-0.13.0-2.el7.x86_64.rpm
yum install bpftrace-0.13.0-2.el7.x86_64.rpm
 bpftrace -e 'k:shrink_active_list { printf("nr_to_scan=%d, lruvec=%p, scan_control=%p, lru=%d, %s \n", arg0, arg1, arg2, arg3, kstack(2)); }'
