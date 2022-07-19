# shuming.github.co

## 1) workingset_refault算法
 workingset.c文件

## 2) LRU_ACTIVE和LRU_INACTIVE list大小平衡算法
inactive_list_is_low()
4.18内核在inactive 和 active page(无论是file lru 还是anon lru), 比例严重失调时回导致系统回收anon page，也就是会swap，尽管当时file lru还有大量的内存页。
``
2513 /*
2514  * This is a basic per-node page freer.  Used by both kswapd and direct reclaim.
2515  */
2516 static void shrink_node_memcg(struct pglist_data *pgdat, struct mem_cgroup *memcg,
2517 >------->------->-------      struct scan_control *sc, unsigned long *lru_pages)
2518 {
2519 >-------struct lruvec *lruvec = mem_cgroup_lruvec(pgdat, memcg);
2520 >-------unsigned long nr[NR_LRU_LISTS];
2521 >-------unsigned long targets[NR_LRU_LISTS];
2522 >-------unsigned long nr_to_scan;
2523 >-------enum lru_list lru;
2524 >-------unsigned long nr_reclaimed = 0;
2525 >-------unsigned long nr_to_reclaim = sc->nr_to_reclaim;
2526 >-------struct blk_plug plug;
2527 >-------bool scan_adjusted;
...
2620 >-------blk_finish_plug(&plug);
2621 >-------sc->nr_reclaimed += nr_reclaimed;
2622 
2623 >-------/*
2624 >------- * Even if we did not try to evict anon pages at all, we want to
2625 >------- * rebalance the anon lru active/inactive ratio.
2626 >------- */
2627 >-------if (inactive_list_is_low(lruvec, false, memcg, sc, true))  《---inactive lru和active lru比例失调
2628 >------->-------shrink_active_list(SWAP_CLUSTER_MAX, lruvec,
2629 >------->------->------->-------   sc, LRU_ACTIVE_ANON); 《---回收anon lru，导致swap
2630 }
``


inactive_list_is_low()

## 3)pgdat->lru_lock竞争问题，改为memcg->lru_lock
https://blog.csdn.net/21cnbao/article/details/112455742

容器内存回收触发全局内存回收
代码块
``
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
``
## 4) memcg共享ZONE内存管理带来得隔离性问题
一个memcg缺内存导致在某个zone上直接内存回收，可能回收这个zone上其他memcg内存：__alloc_pages_direct_reclaim()

## 5) memcg回收线程也可能回收zone上其他容器内存：balance_mem_cgroup_pgdat()

## 6) 内存碎片整理算法
如何确定系统有大量碎片适合整理碎片：kcompactd_node_suitable（）

碎片整理有可能要消耗大量CPU

## 7) Huge memory对内存回收和碎片整理算法影响
## 8) MEMCG memory protection原理
* memory.min

* mem_cgroup_protected（）函数

* 可以用来保护容器内存

## 9) 容器swap大小为什么可以突破2G限制
## 10) 全局内存回收随机选择容器anon page  swap out
## 11) Anon Page Fault页是先放入inactive list还是active list？File Page cache是先放入inactive list还是active list?
代码块
workingset.c
``
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
 ``
## 12) Mem.free还有富余，为什么会OOM?
* 可能性是宿主机没有内存了，__alloc_pages_slowpath（）最终是从系统的ZONE memory上分配得，如果系统ZONE内存不够了就会OOM。

* 容器中的进程page falut:handle_mm_fault()-->--->__alloc_pages_slowpath()--->out_of_memory（）

* 可能性是容器page cache分配失败，pagecache_get_page()---->_page_cache_alloc()--->__alloc_pages_node()--->__alloc_pages()--->__alloc_pages_nodemask()--->__alloc_pages_slowpath()

## 13) LRU list上得page reference 为什么要用物理页来查询而不是虚拟页？
x86机器原理上，page reference是在pte上，对应得是虚拟地址。从代码上看，用物理页page反查所有mapping好得虚拟地址，只要有referenced就算page reference。

代码块
``
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
 ``
## 14) Memcg的page cache算不算在总内存限制里
代码块
结论是算在总内存限制中
3.10内核代码
 612 static int __add_to_page_cache_locked(struct page *page,
 613 >------->------->------->-------      struct address_space *mapping,
 614 >------->------->------->-------      pgoff_t offset, gfp_t gfp_mask,
 615 >------->------->------->-------      void **shadowp)
 616 {
 617 >-------int error;
 618 
 619 >-------VM_BUG_ON(!PageLocked(page));
 620 >-------VM_BUG_ON(PageSwapBacked(page));
 621 
 622 >-------gfp_mask = mapping_gfp_constraint(mapping, gfp_mask);
 623 
 624 >-------error = mem_cgroup_cache_charge(page, current->mm,
 625 >------->------->------->------->-------gfp_mask & GFP_RECLAIM_MASK); 《---计算在总内存限制中
 626 >-------if (error)
 627 >------->-------goto out;
 628 
 629 >-------error = radix_tree_maybe_preload(gfp_mask & ~__GFP_HIGHMEM);
 630 >-------if (error == 0) {
 631 >------->-------page_cache_get(page);
 632 >------->-------page->mapping = mapping;
 633 >------->-------page->index = offset;
 634 
 635 >------->-------spin_lock_irq(&mapping->tree_lock);
 636 >------->-------error = page_cache_tree_insert(mapping, page, shadowp);
 637 >------->-------if (likely(!error)) {
 638 >------->------->-------__inc_zone_page_state(page, NR_FILE_PAGES);
 639 >------->------->-------spin_unlock_irq(&mapping->tree_lock);
 640 >------->------->-------trace_mm_filemap_add_to_page_cache(page);
 641 >------->-------} else {650 >------->-------mem_cgroup_uncharge_cache_page(page);
 651 out:
 652 >-------return error;
 653 }
 4.18内核
  826 static int __add_to_page_cache_locked(struct page *page,
 827 >------->------->------->-------      struct address_space *mapping,
 828 >------->------->------->-------      pgoff_t offset, gfp_t gfp_mask,
 829 >------->------->------->-------      void **shadowp)
 830 {
 831 >-------int huge = PageHuge(page);
 832 >-------struct mem_cgroup *memcg;
 833 >-------int error;
 834 
 835 >-------VM_BUG_ON_PAGE(!PageLocked(page), page);
 836 >-------VM_BUG_ON_PAGE(PageSwapBacked(page), page);
 837 
 838 >-------if (!huge) {
 839 >------->-------error = mem_cgroup_try_charge(page, current->mm, 《---计算在总内存限制中
 840 >------->------->------->------->-------      gfp_mask, &memcg, false);
 841 >------->-------if (error)
 842 >------->------->-------return error;
 843 >-------}
 844 
 845 >-------error = radix_tree_maybe_preload(gfp_mask & GFP_RECLAIM_MASK);
 846 >-------if (error) {
 847 >------->-------if (!huge)
 848 >------->------->-------mem_cgroup_cancel_charge(page, memcg, false);
 849 >------->-------return error;
 850 >-------}
 851 
 852 >-------get_page(page);
 853 >-------page->mapping = mapping;
 854 >-------page->index = offset;
 855 
 856 >-------xa_lock_irq(&mapping->i_pages);
 874 >-------if (!huge)
 875 >------->-------mem_cgroup_cancel_charge(page, memcg, false);
 876 >-------put_page(page);
 877 >-------return error;
 878 }
 
 ## 15） 当容器内存达到上线后，再分配内存是不是会导致OOM
 ### 第一种情况page cache需要分配新内存，宿主机有空闲内存，但是容器内存上限到了，可能导致死循环
 vfs_read()--->__vfs_read()--->ext4_file_read_iter()--->generic_file_read_iter()--->generic_file_buffered_read()--->generic_file_buffered_read()--->page_cache_sync_readahead()--->force_page_cache_readahead()--->__do_page_cache_readahead()---->__page_cache_alloc()
143 
generic_file_buffered_read()


 /**
2097  * generic_file_buffered_read - generic file read routine
2098  * @iocb:>------the iocb to read
2099  * @iter:>------data destination
2100  * @written:>---already copied
2101  *
2102  * This is a generic file read routine, and uses the
2103  * mapping->a_ops->readpage() function for the actual low-level stuff.
2104  *
2105  * This is really ugly. But the goto's actually try to clarify some
2106  * of the logic when it comes to error handling etc.
2107  */
2108 static ssize_t generic_file_buffered_read(struct kiocb *iocb,
2109 >------->-------struct iov_iter *iter, ssize_t written)
2110 {
2111 >-------struct file *filp = iocb->ki_filp;
2112 >-------struct address_space *mapping = filp->f_mapping;
2113 >-------struct inode *inode = mapping->host;
2114 >-------struct file_ra_state *ra = &filp->f_ra;
2115 >-------loff_t *ppos = &io
2116 >-------pgoff_t index;
2117 >-------pgoff_t last_index;
2118 >-------pgoff_t prev_index;
2119 >-------unsigned long offset;      /* offset into pagecache page */
2120 >-------unsigned int prev_offset;
2121 >-------int error = 0;
2122 
2123 >-------if (unlikely(*ppos >= inode->i_sb->s_maxbytes))
2124 >------->-------return 0;
2125 >-------iov_iter_truncate(iter, inode->i_sb->s_maxbytes);
2126 
2127 >-------index = *ppos >> PAGE_SHIFT;
2128 >-------prev_index = ra->prev_pos >> PAGE_SHIFT;
2129 >-------prev_offset = ra->prev_pos & (PAGE_SIZE-1);
2130 >-------last_index = (*ppos + iter->count + PAGE_SIZE-1) >> PAGE_SHIFT;
2131 >-------offset = *ppos & ~PAGE_MASK;
2132 
2133 >-------for (;;) {
2134 >------->-------struct page *page;
2135 >------->-------pgoff_t end_index;
2136 >------->-------loff_t isize;
2137 >------->-------unsigned long nr, ret;
2138 
2139 >------->-------cond_resched();
2140 find_page:
2141 >------->-------if (fatal_signal_pending(current)) {
2142 >------->------->-------error = -EINTR;
2143 >------->------->-------goto out;
2144 >------->-------}
2145 
2146 >------->-------page = find_get_page(mapping, index);
2147 >------->-------if (!page) {
2148 >------->------->-------if (iocb->ki_flags & IOCB_NOWAIT)
2149 >------->------->------->-------goto would_block;
2150 >------->------->-------page_cache_sync_readahead(mapping,
2151 >------->------->------->------->-------ra, filp,
2152 >------->------->------->------->-------index, last_index - index);
2153 >------->------->-------page = find_get_page(mapping, index);
2154 >------->------->-------if (unlikely(page == NULL))
2155 >------->------->------->-------goto no_cached_page;
2156 >------->-------}
...
2326 no_cached_page:
2327 >------->-------/*
2328 >------->------- * Ok, it wasn't cached, so we need to create a new
2329 >------->------- * page..
2330 >------->------- */
2331 >------->-------page = page_cache_alloc(mapping);<---先分配内存，可能会导致OOM, see: __alloc_pages_slowpath()--->__alloc_pages_may_oom(), 这个OOM是宿主机没内存了
2332 >------->-------if (!page) {
2333 >------->------->-------error = -ENOMEM;
2334 >------->------->-------goto out;
2335 >------->-------}
2336 >------->-------error = add_to_page_cache_lru(page, mapping, index,
2337 >------->------->------->-------mapping_gfp_constraint(mapping, GFP_KERNEL)); <---该页会计入到memcg内存使用量中，see mem_cgroup_try_charge()--->try_charge()--->tsk_is_oom_victim()，注意这个oom是memcg内存上限到了，而不是宿主机缺内存，所以处理就是给这个进程设置退出标志。2040 >------- */
------》给这个进程设置退出标志
try_charge() {
。。。
2041 >-------if (unlikely(tsk_is_oom_victim(current) ||
2042 >------->-------     fatal_signal_pending(current) ||
2043 >------->-------     current->flags & PF_EXITING))
2044 >------->-------goto force;
2045 
。。。
}
-----》
2338 >------->-------if (error) {
2339 >------->------->-------put_page(page);
2340 >------->------->-------if (error == -EEXIST) {
2341 >------->------->------->-------error = 0;
2342 >------->------->------->-------goto find_page;
2343 >------->------->-------}
2344 >------->------->-------goto out;
2345 >------->-------}
2346 >------->-------goto readpage;
2347 >-------}
2348 
2349 would_block:
2350 >-------error = -EAGAIN;
2351 out:
2352 >-------ra->prev_pos = prev_index;
2353 >-------ra->prev_pos <<= PAGE_SHIFT;
2354 >-------ra->prev_pos |= prev_offset;
2355 
2356 >-------*ppos = ((loff_t)index << PAGE_SHIFT) + offset;
2357 >-------file_accessed(filp);
2358 >-------return written ? written : error;
2359 }
144 /*
145  * __do_page_cache_readahead() actually reads a chunk of disk.  It allocates
146  * the pages first, then submits them for I/O. This avoids the very bad
147  * behaviour which would occur if page allocations are causing VM writeback.
148  * We really don't want to intermingle reads and writes like that.
149  *
150  * Returns the number of pages requested, or the maximum amount of I/O allowed.
151  */
152 unsigned int __do_page_cache_readahead(struct address_space *mapping,
153 >------->-------struct file *filp, pgoff_t offset, unsigned long nr_to_read,
154 >------->-------unsigned long lookahead_size)
155 {
156 >-------struct inode *inode = mapping->host;
157 >-------struct page *page;
158 >-------unsigned long end_index;>-------/* The last page we want to read */
159 >-------LIST_HEAD(page_pool);
160 >-------int page_idx;
161 >-------unsigned int nr_pages = 0;
162 >-------loff_t isize = i_size_read(inode);
163 >-------gfp_t gfp_mask = readahead_gfp_mask(mapping);
164 
165 >-------if (isize == 0)
166 >------->-------goto out;
167 
168 >-------end_index = ((isize - 1) >> PAGE_SHIFT);
169 
170 >-------/*
171 >------- * Preallocate as many pages as we will need.
172 >------- */
173 >-------for (page_idx = 0; page_idx < nr_to_read; page_idx++) {
174 >------->-------pgoff_t page_offset = offset + page_idx;
175 
176 >------->-------if (page_offset > end_index)
177 >------->------->-------break;
178 
179 >------->-------rcu_read_lock();
180 >------->-------page = radix_tree_lookup(&mapping->i_pages, page_offset);
181 >------->-------rcu_read_unlock();
182 >------->-------if (page && !radix_tree_exceptional_entry(page)) {
183 >------->------->-------/*
184 >------->------->------- * Page already present?  Kick off the current batch of
185 >------->------->------- * contiguous pages before continuing with the next
186 >------->------->------- * batch.
187 >------->------->------- */
188 >------->------->-------if (nr_pages)
189 >------->------->------->-------read_pages(mapping, filp, &page_pool, nr_pages,
190 >------->------->------->------->------->-------gfp_mask);
191 >------->------->-------nr_pages = 0;
192 >------->------->-------continue;
193 >------->-------}
194 
195 >------->-------page = __page_cache_alloc(gfp_mask); 《---这个新分配的page为什么不加入到memcg中，是因为readahead么？
196 >------->-------if (!page)
197 >------->------->-------break;
198 >------->-------page->index = page_offset;
199 >------->-------list_add(&page->lru, &page_pool);
200 >------->-------if (page_idx == nr_to_read - lookahead_size)
201 >------->------->-------SetPageReadahead(page);
202 >------->-------nr_pages++;
203 >-------}
204 
205 >-------/*
206 >------- * Now start the IO.  We ignore I/O errors - if the page is not
207 >------- * uptodate then the caller will launch readpage again, and
208 >------- * will then handle the error.
209 >------- */
210 >-------if (nr_pages)
211 >------->-------read_pages(mapping, filp, &page_pool, nr_pages, gfp_mask);
212 >-------BUG_ON(!list_empty(&page_pool));
213 out:
214 >-------return nr_pages;
215 }

写路径
block_write_begin()--->grab_cache_page_write_begin()--->pagecache_get_page()
1591* If there is a page cache page, it is returned with an increased refcount.
1592  */
1593 struct page *pagecache_get_page(struct address_space *mapping, pgoff_t offset,
1594 >-------int fgp_flags, gfp_t gfp_mask)
1595 {
1596 >-------struct page *page;
1597 
1598 repeat:
1599 >-------page = find_get_entry(mapping, offset);
1600 >-------if (radix_tree_exceptional_entry(page))
1601 >------->-------page = NULL;
1602 >-------if (!page)
1603 >------->-------goto no_page;
1604 
1605 >-------if (fgp_flags & FGP_LOCK) {
1606 >------->-------if (fgp_flags & FGP_NOWAIT) {
1607 >------->------->-------if (!trylock_page(page)) {
1608 >------->------->------->-------put_page(page);
1609 >------->------->------->-------return NULL;
1610 >------->------->-------}
1611 >------->-------} else {
1612 >------->------->-------lock_page(page);
1613 >------->-------}
1614 
1615 >------->-------/* Has the page been truncated? */
1616 >------->-------if (unlikely(page->mapping != mapping)) {
1617 >------->------->-------unlock_page(page);
1618 >------->------->-------put_page(page);
1619 >------->------->-------goto repeat;
1620 >------->-------}
1621 >------->-------VM_BUG_ON_PAGE(page->index != offset, page);
1622 >-------}
1623 
1624 >-------if (page && (fgp_flags & FGP_ACCESSED))
1625 >------->-------mark_page_accessed(page);
1626 
1627 no_page:
1628 >-------if (!page && (fgp_flags & FGP_CREAT)) {
1629 >------->-------int err;
1630 >------->-------if ((fgp_flags & FGP_WRITE) && mapping_cap_account_dirty(mapping))
1631 >------->------->-------gfp_mask |= __GFP_WRITE;
1632 >------->-------if (fgp_flags & FGP_NOFS)
1633 >------->------->-------gfp_mask &= ~__GFP_FS;
1634 
1635 >------->-------page = __page_cache_alloc(gfp_mask); <---<---先分配内存，可能会导致OOM, see: __alloc_pages_slowpath()--->__alloc_pages_may_oom(), 这个OOM是宿主机没内存了
1636 >------->-------if (!page)
1637 >------->------->-------return NULL;
1638 
1639 >------->-------if (WARN_ON_ONCE(!(fgp_flags & FGP_LOCK)))
1640 >------->------->-------fgp_flags |= FGP_LOCK;
1641 
1642 >------->-------/* Init accessed so avoid atomic mark_page_accessed later */
1643 >------->-------if (fgp_flags & FGP_ACCESSED)
1644 >------->------->-------__SetPageReferenced(page);
1645 
1646 >------->-------err = add_to_page_cache_lru(page, mapping, offset, gfp_mask); <---该页会计入到memcg内存使用量中，see mem_cgroup_try_charge()--->try_charge()--->tsk_is_oom_victim()，注意这个oom是memcg内存上限到了，而不是宿主机缺内存，所以处理就是给这个进程设置退出标志。2040 >------- */
------》给这个进程设置退出标志
try_charge() {
。。。
2041 >-------if (unlikely(tsk_is_oom_victim(current) ||
2042 >------->-------     fatal_signal_pending(current) ||
2043 >------->-------     current->flags & PF_EXITING))
2044 >------->-------goto force;
2045 
。。。
}
-----》
1647 >------->-------if (unlikely(err)) {
1648 >------->------->-------put_page(page);
1649 >------->------->-------page = NULL;
1650 >------->------->-------if (err == -EEXIST)
1651 >------->------->------->-------goto repeat;<---超过内存限制后跳到repeat进入循环，如果容器内存一直没有减少可能死循环
1652 >------->-------}
1653 >-------}
1654 
1655 >-------return page;
1656 }
5.18内核
839 
 840 noinline int __filemap_add_folio(struct address_space *mapping,
 841 >------->-------struct folio *folio, pgoff_t index, gfp_t gfp, void **shadowp)
 842 {
 843 >-------XA_STATE(xas, &mapping->i_pages, index);
 844 >-------int huge = folio_test_hugetlb(folio);
 845 >-------int error;
 846 >-------bool charged = false;
 847 
 848 >-------VM_BUG_ON_FOLIO(!folio_test_locked(folio), folio);
 849 >-------VM_BUG_ON_FOLIO(folio_test_swapbacked(folio), folio);
 850 >-------mapping_set_update(&xas, mapping);
 851 
 852 >-------folio_get(folio);
 853 >-------folio->mapping = mapping;
 854 >-------folio->index = index;
 855 
 856 >-------if (!huge) {
 857 >------->-------error = mem_cgroup_charge(folio, NULL, gfp); 〈---内存超了, 这时候folio已经存储了分配好的内存看代码：do_read_cache_folio（）--->filemap_alloc_folio()
 858 >------->-------VM_BUG_ON_FOLIO(index & (folio_nr_pages(folio) - 1), folio);
 859 >------->-------if (error)
 860 >------->------->-------goto error;
 861 >------->-------charged = true;
 862 >-------}
 863 
 864 >-------gfp &= GFP_RECLAIM_MASK;
 865 
 866 >-------do {
 867 >------->-------unsigned int order = xa_get_order(xas.xa, xas.xa_index);
 868 >------->-------void *entry, *old = NULL;
 869 
 870 >------->-------if (order > folio_order(folio))
 871 >------->------->-------xas_split_alloc(&xas, xa_load(xas.xa, xas.xa_index),
 872 >------->------->------->------->-------order, gfp);
 873 >------->-------xas_lock_irq(&xas);
 874 >------->-------xas_for_each_conflict(&xas, entry) {
 875 >------->------->-------old = entry;
 876 >------->------->-------if (!xa_is_value(entry)) {
 877 >------->------->------->-------xas_set_err(&xas, -EEXIST);
 878 >------->------->------->-------goto unlock;
 879 >------->------->-------}
 880 >------->-------}
 881 
 882 >------->-------if (old) {
 883 >------->------->-------if (shadowp)
 884 >------->------->------->-------*shadowp = old;
885 >------->------->-------/* entry may have been split before we acquired lock */
 886 >------->------->-------order = xa_get_order(xas.xa, xas.xa_index);
 887 >------->------->-------if (order > folio_order(folio)) {
 888 >------->------->------->-------xas_split(&xas, old, order);
 889 >------->------->------->-------xas_reset(&xas);
 890 >------->------->-------}
 891 >------->-------}
 892 
 893 >------->-------xas_store(&xas, folio);
 894 >------->-------if (xas_error(&xas))
 895 >------->------->-------goto unlock;
 896 
 897 >------->-------mapping->nrpages++;
 898 
 899 >------->-------/* hugetlb pages do not participate in page cache accounting */
 900 >------->-------if (!huge)
 901 >------->------->-------__lruvec_stat_add_folio(folio, NR_FILE_PAGES);
 902 unlock:
 903 >------->-------xas_unlock_irq(&xas);
 904 >-------} while (xas_nomem(&xas, gfp));
 905 
 906 >-------if (xas_error(&xas)) {
 907 >------->-------error = xas_error(&xas);
 908 >------->-------if (charged)
 909 >------->------->-------mem_cgroup_uncharge(folio);
 910 >------->-------goto error;
 911 >-------}
 912 
 913 >-------trace_mm_filemap_add_to_page_cache(folio);
 914 >-------return 0;
 915 error:
 916 >-------folio->mapping = NULL;
 917 >-------/* Leave page->index set: truncation relies upon it */
 918 >-------folio_put(folio);
 919 >-------return error;
 920 }
 921 ALLOW_ERROR_INJECTION(__filemap_add_folio, ERRNO);
 
 ### 第二种情况page fault handler中
 有一种情况是try_charge()时超了内存上线，但是try_charge(）只是标记一下OOM了和在进程mm上标记具体memcg，然后page fault的时候调mem_cgroup_out_of_memory（）

第一种case ext4 文件系统，filemap

[20148497.767284] java invoked oom-killer: gfp_mask=0x6200ca(GFP_HIGHUSER_MOVABLE), nodemask=(null), order=0, oom_score_adj=916
[20148497.768021] java cpuset=docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope mems_allowed=0-3
[20148497.768802] CPU: 18 PID: 7127 Comm: java Kdump: loaded Tainted: G        W  O  K  --------- -  - 4.18.0-147.mt20200626.413.el8_1.x86_64 #1
[20148497.770281] Hardware name: Dell Inc. PowerEdge R7415/065PKD, BIOS 1.15.0 09/11/2020
[20148497.770986] Call Trace:
[20148497.771697]  dump_stack+0x5c/0x80
[20148497.772401]  dump_header+0x6e/0x27a
[20148497.773152]  oom_kill_process.cold.29+0xb/0x10
[20148497.773891]  out_of_memory+0x1ba/0x4b0
[20148497.774636]  mem_cgroup_out_of_memory+0x49/0x80《---注意mem_cgroup_out_of_memory()并不是被try_charge()直接调用，大概是try_charge()标记了自己的调用栈，page fault handler会打印出来。
[20148497.775336]  try_charge+0x6f1/0x770
[20148497.776029]  mem_cgroup_try_charge+0x8b/0x1a0
[20148497.776723]  __add_to_page_cache_locked+0x64/0x240
[20148497.777417]  add_to_page_cache_lru+0x64/0x100
[20148497.778109]  filemap_fault+0x3f1/0x860
[20148497.778803]  ? alloc_set_pte+0x203/0x480
[20148497.779556]  ? filemap_map_pages+0x1ed/0x3a0
[20148497.780266]  ext4_filemap_fault+0x2c/0x40 [ext4]
[20148497.780964]  __do_fault+0x38/0xc0
[20148497.781656]  do_fault+0x18d/0x3e0
[20148497.782347]  __handle_mm_fault+0x539/0x6b0
[20148497.783042]  handle_mm_fault+0xda/0x200
[20148497.783736]  __do_page_fault+0x22b/0x4e0
[20148497.784437]  do_page_fault+0x32/0x110
[20148497.785166]  ? page_fault+0x8/0x30
[20148497.785862]  page_fault+0x1e/0x30
[20148497.786566] RIP: 0033:0x7f00417e1ae0
[20148497.787260] Code: Bad RIP value.
[20148497.787940] RSP: 002b:00007f002af77ae8 EFLAGS: 00010206
[20148497.788627] RAX: 00007f002af77ba0 RBX: 00000007c04ab448 RCX: 0000000796b37a88
[20148497.789361] RDX: 00007f0041df8a70 RSI: 00000007c04ab448 RDI: 00007f002af77ba0
[20148497.790094] RBP: 00007f002af77b10 R08: 00007f0041e213a0 R09: 00007f0041e4e8d0
[20148497.790842] R10: 00000000f2d4ff2a R11: 00007f004182c430 R12: 00007f002af77ba0
[20148497.791521] R13: 00007f002af77b90 R14: 00007f002af77be0 R15: 0000000000000000
[20148497.792301] Task in /kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podd63c4bbe_5f18_11ec_bdcd_d094668d7dd6.slice/docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope killed as a result of limit of /kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podd63c4bbe_5f18_11ec_bdcd_d094668d7dd6.slice/docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope
[20148497.795200] memory: usage 32461120kB, limit 33554432kB, failcnt 0
[20148497.795959] memory+swap: usage 35651584kB, limit 35651584kB, failcnt 24892068
[20148497.796693] kmem: usage 471440kB, limit 9007199254740988kB, failcnt 0
[20148497.797405] Memory cgroup stats for /kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podd63c4bbe_5f18_11ec_bdcd_d094668d7dd6.slice/docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope: cache:28030012KB rss:3958288KB rss_huge:0KB shmem:28013264KB mapped_file:25212KB dirty:0KB writeback:1716KB swap:3190836KB inactive_anon:11333716KB active_anon:20641940KB inactive_file:7596KB active_file:468KB unevictable:0KB
[20148497.800391] Memory cgroup out of memory: Killed process 7093 (java) total-vm:11451920kB, anon-rss:1968776kB, file-rss:0kB, shmem-rss:16356kB
[20148497.993482] oom_reaper: reaped process 7093 (java), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB


第二种case shmem

[20148402.291616] java invoked oom-killer: gfp_mask=0x6200ca(GFP_HIGHUSER_MOVABLE), nodemask=(null), order=0, oom_score_adj=916
[20148402.292342] java cpuset=docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope mems_allowed=0-3
[20148402.293103] CPU: 14 PID: 48975 Comm: java Kdump: loaded Tainted: G        W  O  K  --------- -  - 4.18.0-147.mt20200626.413.el8_1.x86_64 #1
[20148402.294435] Hardware name: Dell Inc. PowerEdge R7415/065PKD, BIOS 1.15.0 09/11/2020
[20148402.295126] Call Trace:
[20148402.295823]  dump_stack+0x5c/0x80
[20148402.296514]  dump_header+0x6e/0x27a
[20148402.297239]  oom_kill_process.cold.29+0xb/0x10
[20148402.297994]  out_of_memory+0x1ba/0x4b0
[20148402.298682]  mem_cgroup_out_of_memory+0x49/0x80
[20148402.299371]  try_charge+0x6f1/0x770
[20148402.300055]  mem_cgroup_try_charge+0x8b/0x1a0
[20148402.300741]  mem_cgroup_try_charge_delay+0x1c/0x40
[20148402.301473]  shmem_getpage_gfp+0x684/0xcc0
[20148402.302172]  ? _cond_resched+0x15/0x30
[20148402.303063]  shmem_write_begin+0x35/0x60
[20148402.303748]  generic_perform_write+0xf4/0x1b0
[20148402.304433]  __generic_file_write_iter+0xfa/0x1c0
[20148402.305171]  generic_file_write_iter+0xab/0x150
[20148402.305884]  new_sync_write+0x124/0x170
[20148402.306571]  vfs_write+0xa5/0x1a0
[20148402.307262]  ksys_write+0x4f/0xb0
[20148402.308083]  do_syscall_64+0x5b/0x1b0
[20148402.308819]  entry_SYSCALL_64_after_hwframe+0x65/0xca
[20148402.309543] RIP: 0033:0x7faf0af126fd
[20148402.310241] Code: cd 20 00 00 75 10 b8 01 00 00 00 0f 05 48 3d 01 f0 ff ff 73 31 c3 48 83 ec 08 e8 4e fd ff ff 48 89 04 24 b8 01 00 00 00 0f 05 <48> 8b 3c 24 48 89 c2 e8 97 fd ff ff 48 89 d0 48 83 c4 08 48 3d 01
[20148402.311743] RSP: 002b:00007faf0b32de40 EFLAGS: 00000293 ORIG_RAX: 0000000000000001
[20148402.312505] RAX: ffffffffffffffda RBX: 0000000000000032 RCX: 00007faf0af126fd
[20148402.313255] RDX: 0000000000000200 RSI: 00007faf0b32dea0 RDI: 0000000000000094
[20148402.314026] RBP: 00007faf0b32de70 R08: 57a63dbca779412b R09: 000000072e583030
[20148402.314793] R10: 000000000000017e R11: 0000000000000293 R12: 0000000000000200
[20148402.315546] R13: 00007faf0b32dea0 R14: 0000000000000094 R15: 0000000000000000
[20148402.316412] Task in /kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podd63c4bbe_5f18_11ec_bdcd_d094668d7dd6.slice/docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope killed as a result of limit of /kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podd63c4bbe_5f18_11ec_bdcd_d094668d7dd6.slice/docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope
[20148402.319608] memory: usage 32461112kB, limit 33554432kB, failcnt 0
[20148402.320419] memory+swap: usage 35651584kB, limit 35651584kB, failcnt 24208655
[20148402.321233] kmem: usage 478036kB, limit 9007199254740988kB, failcnt 0
[20148402.322046] Memory cgroup stats for /kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podd63c4bbe_5f18_11ec_bdcd_d094668d7dd6.slice/docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope: cache:27747820KB rss:4233580KB rss_huge:0KB shmem:27731164KB mapped_file:11880KB dirty:0KB writeback:1716KB swap:3190836KB inactive_anon:11311424KB active_anon:20656120KB inactive_file:10400KB active_file:4324KB unevictable:0KB
[20148402.325486] Memory cgroup out of memory: Killed process 321688 (java) total-vm:10247356kB, anon-rss:2740520kB, file-rss:0kB, shmem-rss:0kB

第三种case anon memory

[20219668.716979] java invoked oom-killer: gfp_mask=0x6000c0(GFP_KERNEL), nodemask=(null), order=0, oom_score_adj=916
[20219668.717885] java cpuset=docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope mems_allowed=0-3
[20219668.718723] CPU: 31 PID: 164878 Comm: java Kdump: loaded Tainted: G        W  O  K  --------- -  - 4.18.0-147.mt20200626.413.el8_1.x86_64 #1
[20219668.720370] Hardware name: Dell Inc. PowerEdge R7415/065PKD, BIOS 1.15.0 09/11/2020
[20219668.721472] Call Trace:
[20219668.722344]  dump_stack+0x5c/0x80
[20219668.723282]  dump_header+0x6e/0x27a
[20219668.724345]  oom_kill_process.cold.29+0xb/0x10
[20219668.725241]  out_of_memory+0x1ba/0x4b0
[20219668.726123]  mem_cgroup_out_of_memory+0x49/0x80
[20219668.726924]  try_charge+0x6f1/0x770
[20219668.727754]  ? __alloc_pages_nodemask+0xef/0x280
[20219668.728555]  mem_cgroup_try_charge+0x8b/0x1a0
[20219668.729373]  mem_cgroup_try_charge_delay+0x1c/0x40
[20219668.730133]  do_anonymous_page+0xb5/0x370
[20219668.730938]  ? do_numa_page+0x25a/0x280
[20219668.731734]  __handle_mm_fault+0x66e/0x6b0
[20219668.732716]  handle_mm_fault+0xda/0x200
[20219668.733671]  __do_page_fault+0x22b/0x4e0
[20219668.734729]  do_page_fault+0x32/0x110
[20219668.735747]  ? page_fault+0x8/0x30
[20219668.736741]  page_fault+0x1e/0x30
[20219668.737846] RIP: 0033:0x7f88f77e3336
[20219668.738752] Code: 60 4c 8b d0 49 83 c2 18 4d 3b 57 70 0f 83 90 00 00 00 4d 89 57 60 41 0f 18 82 00 01 00 00 4c 8b 54 24 20 4d 8b 92 a8 00 00 00 <4c> 89 10 c7 40 08 c0 6c 05 f8 44 89 60 0c 4c 89 60 10 44 8b 55 0c
[20219668.740226] RSP: 002b:00007f890bffc120 EFLAGS: 00010287
[20219668.740824] RAX: 000000077e7b5000 RBX: 000000000000064b RCX: 000000000000064a
[20219668.741472] RDX: 00000000ef940229 RSI: 00000000f8056cc0 RDI: 000000077ca01148
[20219668.742203] RBP: 000000077e7ab910 R08: 00007f89052e3000 R09: 000000076c2f3650
[20219668.742909] R10: 0000000000000005 R11: 00000000efcf5722 R12: 0000000000000000
[20219668.743561] R13: 000000000000088c R14: 000000076c2f3618 R15: 00007f890400a000
[20219668.744406] Task in /kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podd63c4bbe_5f18_11ec_bdcd_d094668d7dd6.slice/docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope killed as a result of limit of /kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podd63c4bbe_5f18_11ec_bdcd_d094668d7dd6.slice/docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope
[20219668.747512] memory: usage 33421628kB, limit 33554432kB, failcnt 0
[20219668.748390] memory+swap: usage 35651584kB, limit 35651584kB, failcnt 61602
[20219668.749326] kmem: usage 497680kB, limit 9007199254740988kB, failcnt 0
[20219668.750146] Memory cgroup stats for /kubepods.slice/kubepods-burstable.slice/kubepods-burstable-podd63c4bbe_5f18_11ec_bdcd_d094668d7dd6.slice/docker-083afd1a06b8b612ab5d974e12200d7fd1d35be6a44f0e368179399ef6c6e84d.scope: cache:23708180KB rss:9214840KB rss_huge:0KB shmem:23689196KB mapped_file:32340KB dirty:0KB writeback:2376KB swap:2228952KB inactive_anon:7860516KB active_anon:25044932KB inactive_file:10828KB active_file:552KB unevictable:0KB
[20219668.753688] Memory cgroup out of memory: Killed process 281482 (java) total-vm:10481240kB, anon-rss:3690112kB, file-rss:0kB, shmem-rss:0kB
[20219669.132460] oom_reaper: reaped process 281482 (java), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB
