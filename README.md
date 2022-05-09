# shuming.github.co

1) workingset_refault算法
 workingset.c文件

2) LRU_ACTIVE和LRU_INACTIVE list大小平衡算法
inactive_list_is_low()

3)pgdat->lru_lock竞争问题，改为memcg->lru_lock
https://blog.csdn.net/21cnbao/article/details/112455742

容器内存回收触发全局内存回收
代码块
3770 #ifdef CONFIG_MEMCG
3771 /*
3772  * Per cgroup background reclaim.
3773  * For memory cgroup kswaped thread, balance_mem_cgroup_pgdat() will work across all
3774  * node's zones until the memory cgroup at its high_wmark_limit.
3775  */
3776 static unsigned long balance_mem_cgroup_pgdat(struct mem_cgroup *memcg, int order)
3777 {
3778 >-------unsigned long total_scanned;
3779 >-------unsigned long total_reclaimed;
3780 >-------int nid;
3781 >-------pg_data_t *pgdat;
3782 >-------int start_node;
3783 >-------int loop;
3784 >-------int innerloop;
3785 >-------bool wmark_ok;
3786 >-------struct scan_control sc = {
3787 >------->-------.gfp_mask = GFP_KERNEL,
3788 >------->-------.reclaim_idx = MAX_NR_ZONES - 1,
3789 >------->-------.order = order,
3790 >------->-------.may_unmap = 1,
3791 >------->-------.may_swap = 0,
3792 >------->-------.may_writepage = !laptop_mode,
3793 >------->-------.target_mem_cgroup = memcg, <---对应容器的memcg
3794 >------->-------.priority = DEF_PRIORITY,
3795 >-------};
3796 >-------total_reclaimed = 0;
...
3803 >-------do {
3804 >------->-------bool raise_priority = false;
3805 >------->-------innerloop = 0;
3806
3807 >------->-------// Loop on every node
3808 >------->-------while (1) {
3809 >------->------->-------nid = mem_cgroup_select_victim_node(memcg);<---轮流选择numa node回收memcg内存，如果memcg绑定node，可能会空转一轮。
3810 >------->------->-------if (innerloop == 0) {
3811 >------->------->------->-------start_node = nid;
3812 >------->------->------->-------innerloop++;
3813 >------->------->-------}else if (nid == start_node)
3814 >------->------->------->-------break;
3815
3816 >------->------->-------pgdat = NODE_DATA(nid);
3817
3818 >------->------->-------shrink_node(pgdat, &sc);<---回收memcg对应numa node上的内存
3819
3820 >------->------->-------if (!sc.nr_reclaimed)
3821 >------->------->------->-------raise_priority = true;
3822 >------->------->-------total_scanned += sc.nr_scanned;
3823 >------->------->-------total_reclaimed += sc.nr_reclaimed;
3824
3825 >------->------->-------snapshot_refaults(memcg, pgdat);
3826 >------->------->-------count_memcg_events(memcg, PAGEOUTRUN, 1);
3827 >------->------->-------if (mem_cgroup_watermark_ok(memcg, CHARGE_WMARK_HIGH)) {
3828 >------->------->------->-------wmark_ok = true;
3829 >------->------->------->-------goto out;
3830 >------->------->-------}
3831 >------->-------}
3832
3833 >------->-------loop++;
3834
3835 >------->-------if (total_scanned && sc.priority < DEF_PRIORITY - 2)
3836 >------->------->-------congestion_wait(WRITE, HZ/10);
4) memcg共享ZONE内存管理带来得隔离性问题
一个memcg缺内存导致在某个zone上直接内存回收，可能回收这个zone上其他memcg内存：__alloc_pages_direct_reclaim()

5) memcg回收线程也可能回收zone上其他容器内存：balance_mem_cgroup_pgdat()

6) 内存碎片整理算法
如何确定系统有大量碎片适合整理碎片：kcompactd_node_suitable（）

碎片整理有可能要消耗大量CPU

7) Huge memory对内存回收和碎片整理算法影响
MEMCG memory protection原理
memory.min

mem_cgroup_protected（）函数

可以用来保护容器内存

8) 容器swap大小为什么可以突破2G限制
全局内存回收随机选择容器anon page  swap out
9) Anon Page Fault页是先放入inactive list还是active list？File Page cache是先放入inactive list还是active list?
代码块
workingset.c
 /*
 20  *>----->-------Double CLOCK lists
 21  *
 22  * Per node, two clock lists are maintained for file pages: the
 23  * inactive and the active list.  Freshly faulted pages start out at
 24  * the head of the inactive list and page reclaim scans pages from the
 25  * tail.  Pages that are accessed multiple times on the inactive list
 26  * are promoted to the active list, to protect them from reclaim,
 27  * whereas active pages are demoted to the inactive list when the
 28  * active list grows too big.
 29  *
 30  *   fault ------------------------+
 31  *                                 |
 32  *              +--------------+   |            +-------------+
 33  *   reclaim <- |   inactive   | <-+-- demotion |    active   | <--+
 34  *              +--------------+                +-------------+    |
 35  *                     |                                           |
 36  *                     +-------------- promotion ------------------+
 37  *
 38  *
 39  *>----->-------Access frequency and refault distance
10) Mem.free还有富余，为什么会OOM?
第一种可能性是宿主机没有内存了，

11) LRU list上得page reference 为什么要用物理页来查询而不是虚拟页？
x86机器原理上，page reference是在pte上，对应得是虚拟地址。从代码上看，用物理页page反查所有mapping好得虚拟地址，只要有referenced就算page reference。

代码块
826 /**
 827  * page_referenced - test if the page was referenced
 828  * @page: the page to test
 829  * @is_locked: caller holds lock on the page
 830  * @memcg: target memory cgroup
 831  * @vm_flags: collect encountered vma->vm_flags who actually referenced the page
 832  *
 833  * Quick test_and_clear_referenced for all mappings to a page,
 834  * returns the number of ptes which referenced the page.
 835  */
 836 int page_referenced(struct page *page,
 837 >------->-------    int is_locked,
 838 >------->-------    struct mem_cgroup *memcg,
 839 >------->-------    unsigned long *vm_flags)
 840 {
 841 >-------int we_locked = 0;
 842 >-------struct page_referenced_arg pra = {
 843 >------->-------.mapcount = total_mapcount(page),
 844 >------->-------.memcg = memcg,
 845 >-------};
 846 >-------struct rmap_walk_control rwc = {
 847 >------->-------.rmap_one = page_referenced_one,
 848 >------->-------.arg = (void *)&pra,
 849 >------->-------.anon_lock = page_lock_anon_vma_read,
 850 >-------};
 851
 852 >-------*vm_flags = 0;
 853 >-------if (!page_mapped(page))
 854 >------->-------return 0;
 855
 856 >-------if (!page_rmapping(page))
 857 >------->-------return 0;
 858
 859 >-------if (!is_locked && (!PageAnon(page) || PageKsm(page))) {
 860 >------->-------we_locked = trylock_page(page);
 861 >------->-------if (!we_locked)
 862 >------->------->-------return 1;
 863 >-------}
 864
 865 >-------/*
 866 >------- * If we are reclaiming on behalf of a cgroup, skip
 867 >------- * counting on behalf of references from different
 868 >------- * cgroups
 869 >------- */
 870 >-------if (memcg) {
 871 >------->-------rwc.invalid_vma = invalid_page_referenced_vma;
 872 >-------}
 873
 874 >-------rmap_walk(page, &rwc);
 875 >-------*vm_flags = pra.vm_flags;
 876
 877 >-------if (we_locked)
 878 >------->-------unlock_page(page);
 879
 880 >-------return pra.referenced;
 881 }
12) Memcg的page cache算不算在总内存限制里
代码块
​
