# shuming.github.co

## 1) workingset_refault算法
 workingset.c文件

## 2) LRU_ACTIVE和LRU_INACTIVE list大小平衡算法
inactive_list_is_low()
4.18内核在inactive 和 active page(无论是file lru 还是anon lru), 比例严重失调时回导致系统回收anon page，也就是会swap，尽管当时file lru还有大量的内存页。
```
2204 /*
2205  * The inactive anon list should be small enough that the VM never has
2206  * to do too much work.
2207  *
2208  * The inactive file list should be small enough to leave most memory
2209  * to the established workingset on the scan-resistant active list,
2210  * but large enough to avoid thrashing the aggregate readahead window.
2211  *
2212  * Both inactive lists should also be large enough that each inactive
2213  * page has a chance to be referenced again before it is reclaimed.
2214  *
2215  * If that fails and refaulting is observed, the inactive list grows.
2216  *
2217  * The inactive_ratio is the target ratio of ACTIVE to INACTIVE pages
2218  * on this LRU, maintained by the pageout code. An inactive_ratio
2219  * of 3 means 3:1 or 25% of the pages are kept on the inactive list.
2220  *
2221  * total     target    max
2222  * memory    ratio     inactive
2223  * -------------------------------------
2224  *   10MB       1         5MB
2225  *  100MB       1        50MB
2226  *    1GB       3       250MB
2227  *   10GB      10       0.9GB
2228  *  100GB      31         3GB
2229  *    1TB     101        10GB
2230  *   10TB     320        32GB
2231  */

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
```


inactive_list_is_low()

## 3)pgdat->lru_lock竞争问题，改为memcg->lru_lock
https://blog.csdn.net/21cnbao/article/details/112455742

容器内存回收触发全局内存回收
代码块

```
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
```
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
```
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
 ```
## 12) Mem.free还有富余，为什么会OOM?
* 可能性是宿主机没有内存了，__alloc_pages_slowpath（）最终是从系统的ZONE memory上分配得，如果系统ZONE内存不够了就会OOM。

* 容器中的进程page falut:handle_mm_fault()-->--->__alloc_pages_slowpath()--->out_of_memory（）

* 可能性是容器page cache分配失败，pagecache_get_page()---->_page_cache_alloc()--->__alloc_pages_node()--->__alloc_pages()--->__alloc_pages_nodemask()--->__alloc_pages_slowpath()

## 13) LRU list上得page reference 为什么要用物理页来查询而不是虚拟页？
x86机器原理上，page reference是在pte上，对应得是虚拟地址。从代码上看，用物理页page反查所有mapping好得虚拟地址，只要有referenced就算page reference。

代码块
```
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
 ```
## 14) Memcg的page cache算不算在总内存限制里
代码块
结论是算在总内存限制中
3.10内核代码
```
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
 ```
 4.18内核
 ```
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
 ```
 ## 15） 当容器内存达到上线后，再分配内存是不是会导致OOM
 ### 第一种情况page cache需要分配新内存，宿主机有空闲内存，但是容器内存上限到了，可能导致死循环

vfs_read()--->__vfs_read()--->ext4_file_read_iter()--->generic_file_read_iter()--->generic_file_buffered_read()--->generic_file_buffered_read()--->page_cache_sync_readahead()--->force_page_cache_readahead()--->__do_page_cache_readahead()---->__page_cache_alloc()

generic_file_buffered_read()
```
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
```
```
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
```
```
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
```
5.18内核
839 
```
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
 ```
 ### 第二种情况page fault handler中
 有一种情况是try_charge()时超了内存上线，但是try_charge(）只是标记一下OOM了和在进程mm上标记具体memcg，然后page fault的时候调mem_cgroup_out_of_memory（）

#### 第一种case ext4 文件系统，filemap
```
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
```

#### 第二种case shmem
```
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
```
#### 第三种case anon memory
```
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
```
```
__handle_mm_fault()--->handle_pte_fault()--->do_anonymous_page()
static int __handle_mm_fault(struct vm_area_struct *vma, unsigned long address,
4041 >------->-------unsigned int flags)
4042 {
4043 >-------struct vm_fault vmf = {
4044 >------->-------.vma = vma,
4045 >------->-------.address = address & PAGE_MASK,
4046 >------->-------.flags = flags,
4047 >------->-------.pgoff = linear_page_index(vma, address),
4048 >------->-------.gfp_mask = __get_fault_gfp_mask(vma),
4049 >-------};
4050 >-------unsigned int dirty = flags & FAULT_FLAG_WRITE;
4051 >-------struct mm_struct *mm = vma->vm_mm;
4052 >-------pgd_t *pgd;
4053 >-------p4d_t *p4d;
4054 >-------int ret;
4055 
4056 >-------pgd = pgd_offset(mm, address);
4057 >-------p4d = p4d_alloc(mm, pgd, address);
4058 >-------if (!p4d)
4059 >------->-------return VM_FAULT_OOM;
4060 
4061 >-------vmf.pud = pud_alloc(mm, p4d, address);
4062 >-------if (!vmf.pud)
4063 >------->-------return VM_FAULT_OOM; <---oom
4064 >-------if (pud_none(*vmf.pud) && transparent_hugepage_enabled(vma)) {
4065 >------->-------ret = create_huge_pud(&vmf);
4066 >------->-------if (!(ret & VM_FAULT_FALLBACK))
4067 >------->------->-------return ret;
4068 >-------} else {
4069 >------->-------pud_t orig_pud = *vmf.pud;
4097 >------->-------barrier();
4098 >------->-------if (unlikely(is_swap_pmd(orig_pmd))) {
4099 >------->------->-------VM_BUG_ON(thp_migration_supported() &&
4100 >------->------->------->------->-------  !is_pmd_migration_entry(orig_pmd));
4101 >------->------->-------if (is_pmd_migration_entry(orig_pmd))
4102 >------->------->------->-------pmd_migration_entry_wait(mm, vmf.pmd);
4103 >------->------->-------return 0;
4104 >------->-------}
4105 >------->-------if (pmd_trans_huge(orig_pmd) || pmd_devmap(orig_pmd)) {
4106 >------->------->-------if (pmd_protnone(orig_pmd) && vma_is_accessible(vma))
4107 >------->------->------->-------return do_huge_pmd_numa_page(&vmf, orig_pmd);
4108 
4109 >------->------->-------if (dirty && !pmd_write(orig_pmd)) {
4110 >------->------->------->-------ret = wp_huge_pmd(&vmf, orig_pmd);
4111 >------->------->------->-------if (!(ret & VM_FAULT_FALLBACK))
4112 >------->------->------->------->-------return ret;
4113 >------->------->-------} else {
4114 >------->------->------->-------huge_pmd_set_accessed(&vmf, orig_pmd);
4115 >------->------->------->-------return 0;
4116 >------->------->-------}
4117 >------->-------}
4118 >-------}
4119 
4120 >-------return handle_pte_fault(&vmf);
4121 }
3128  * We enter with non-exclusive mmap_sem (to exclude vma changes,
3129  * but allow concurrent faults), and pte mapped but not yet locked.
3130  * We return with mmap_sem still held, but pte unmapped and unlocked.
3131  */
3132 static int do_anonymous_page(struct vm_fault *vmf)
3133 {
3134 >-------struct vm_area_struct *vma = vmf->vma;
3135 >-------struct mem_cgroup *memcg;
3136 >-------struct page *page;
3137 >-------int ret = 0;
3138 >-------pte_t entry;
3139 
3140 >-------/* File mapping without ->vm_ops ? */
3141 >-------if (vma->vm_flags & VM_SHARED)
3142 >------->-------return VM_FAULT_SIGBUS;
3143 
3144 >-------/*
3145 >------- * Use pte_alloc() instead of pte_alloc_map().  We can't run
3146 >------- * pte_offset_map() on pmds where a huge pmd might be created
3147 >------- * from a different thread.
3148 >------- *
3149 >------- * pte_alloc_map() is safe to use under down_write(mmap_sem) or when
3150 >------- * parallel threads are excluded by other means.
3151 >------- *
3152 >------- * Here we only have down_read(mmap_sem).
3153 >------- */
3154 >-------if (pte_alloc(vma->vm_mm, vmf->pmd, vmf->address))
3155 >------->-------return VM_FAULT_OOM;
3157 >-------/* See the comment in pte_alloc_one_map() */
3158 >-------if (unlikely(pmd_trans_unstable(vmf->pmd)))
3159 >------->-------return 0;
3160 
3161 >-------/* Use the zero-page for reads */
3162 >-------if (!(vmf->flags & FAULT_FLAG_WRITE) &&
3163 >------->------->-------!mm_forbids_zeropage(vma->vm_mm)) {
3164 >------->-------entry = pte_mkspecial(pfn_pte(my_zero_pfn(vmf->address),
3165 >------->------->------->------->------->-------vma->vm_page_prot));
3166 >------->-------vmf->pte = pte_offset_map_lock(vma->vm_mm, vmf->pmd,
3167 >------->------->------->-------vmf->address, &vmf->ptl);
3168 >------->-------if (!pte_none(*vmf->pte))
3169 >------->------->-------goto unlock;
3170 >------->-------ret = check_stable_address_space(vma->vm_mm);
3171 >------->-------if (ret)
3172 >------->------->-------goto unlock;
3173 >------->-------/* Deliver the page fault to userland, check inside PT lock */
3174 >------->-------if (userfaultfd_missing(vma)) {
3175 >------->------->-------pte_unmap_unlock(vmf->pte, vmf->ptl);
3176 >------->------->-------return handle_userfault(vmf, VM_UFFD_MISSING);
3177 >------->-------}
3178 >------->-------goto setpte;
3179 >-------}
3180 
3181 >-------/* Allocate our own private page. */
3182 >-------if (unlikely(anon_vma_prepare(vma)))
3183 >------->-------goto oom;
3184 >-------page = alloc_zeroed_user_highpage_movable(vma, vmf->address);
3185 >-------if (!page)
3186 >------->-------goto oom;
3187 
3188 >-------if (mem_cgroup_try_charge_delay(page, vma->vm_mm, GFP_KERNEL, &memcg,
3189 >------->------->------->------->-------false)) <----超内存限制了
3190 >------->-------goto oom_free_page; 
3191 
3192 >-------/*
3193 >------- * The memory barrier inside __SetPageUptodate makes sure that
3194 >------- * preceeding stores to the page contents become visible before

3195 >------- * the set_pte_at() write.
3196 >------- */
3197 >-------__SetPageUptodate(page);
3198 
3199 >-------entry = mk_pte(page, vma->vm_page_prot);
3200 >-------if (vma->vm_flags & VM_WRITE)
3201 >------->-------entry = pte_mkwrite(pte_mkdirty(entry));
3202 
3203 >-------vmf->pte = pte_offset_map_lock(vma->vm_mm, vmf->pmd, vmf->address,
3204 >------->------->-------&vmf->ptl);
3205 >-------if (!pte_none(*vmf->pte))
3206 >------->-------goto release;
3207 
3208 >-------ret = check_stable_address_space(vma->vm_mm);
3209 >-------if (ret)
3210 >------->-------goto release;
3211 
3212 >-------/* Deliver the page fault to userland, check inside PT lock */
3213 >-------if (userfaultfd_missing(vma)) {
3214 >------->-------pte_unmap_unlock(vmf->pte, vmf->ptl);
3215 >------->-------mem_cgroup_cancel_charge(page, memcg, false);
3216 >------->-------put_page(page);
3217 >------->-------return handle_userfault(vmf, VM_UFFD_MISSING);
3218 >-------}
3219 
3220 >-------inc_mm_counter_fast(vma->vm_mm, MM_ANONPAGES);
3221 >-------page_add_new_anon_rmap(page, vma, vmf->address, false);
3222 >-------mem_cgroup_commit_charge(page, memcg, false, false);
3223 >-------lru_cache_add_active_or_unevictable(page, vma);
3224 setpte:
3225 >-------set_pte_at(vma->vm_mm, vmf->address, vmf->pte, entry);
3226 
3227 >-------/* No need to invalidate - it was non-present before */
3228 >-------update_mmu_cache(vma, vmf->address, vmf->pte);
3229 unlock:
3230 >-------pte_unmap_unlock(vmf->pte, vmf->ptl);
3231 >-------return ret;
3232 release:
3233 >-------mem_cgroup_cancel_charge(page, memcg, false);
3234 >-------put_page(page);
3235 >-------goto unlock;
3236 oom_free_page:
3237 >-------put_page(page);
3238 oom:
3239 >-------return VM_FAULT_OOM; 《---oom了
3240 }
还有除了anonymous page之外的page fault handler也会在容器内存超过上限时返回oom
do_page_fault()--->__do_fault()--->ext4_filemap_fault()--->filemap_fault()--->add_to_page_cache_lru()--->__add_to_page_cache_locked()--->mem_cgroup_try_charge()--->try_charge()--->mem_cgroup_out_of_memory()
```
### 第三种情况slab/slub中
```
1393 /*
1394  * Interface to system's page allocator. No need to hold the
1395  * kmem_cache_node ->list_lock.
1396  *
1397  * If we requested dmaable memory, we will get it. Even if we
1398  * did not request dmaable memory, we might get it, but that
1399  * would be relatively rare and ignorable.
1400  */
1401 static struct page *kmem_getpages(struct kmem_cache *cachep, gfp_t flags,
1402 >------->------->------->------->------->------->------->-------int nodeid)
1403 {
1404 >-------struct page *page;
1405 >-------int nr_pages;
1406 
1407 >-------flags |= cachep->allocflags;
1408 
1409 >-------page = __alloc_pages_node(nodeid, flags, cachep->gfporder);
1410 >-------if (!page) {
1411 >------->-------slab_out_of_memory(cachep, flags, nodeid);
1412 >------->-------return NULL;
1413 >-------}
1414 
1415 >-------if (memcg_charge_slab(page, flags, cachep->gfporder, cachep)) {  <---整个slab都charge在一个memcg上，其他memcg会不会用这个slab?   memcg_kmem_charge_memc()--->try_charge()--->mem_cgroup_oom()
1416 >------->-------__free_pages(page, cachep->gfporder);
1417 >------->-------return NULL;
1418 >-------}
1419 
1420 >-------nr_pages = (1 << cachep->gfporder);
1421 >-------if (cachep->flags & SLAB_RECLAIM_ACCOUNT)
1422 >------->-------mod_lruvec_page_state(page, NR_SLAB_RECLAIMABLE, nr_pages);
1423 >-------else
1424 >------->-------mod_lruvec_page_state(page, NR_SLAB_UNRECLAIMABLE, nr_pages);
1425 
1426 >-------__SetPageSlab(page);
1427 >-------/* Record if ALLOC_NO_WATERMARKS was set when allocating the slab */
1428 >-------if (sk_memalloc_socks() && page_is_pfmemalloc(page))
1429 >------->-------SetPageSlabPfmemalloc(page);
1430 
1431 >-------return page;
1432 }
```
## 共享内存到底算page cache还是anon memory，共享内存(share memory)对memcg如何计数
```
1611 /*
1612  * shmem_getpage_gfp - find page in cache, or get from swap, or allocate
1613  *
1614  * If we allocate a new one we do not mark it dirty. That's up to the
1615  * vm. If we swap it in we mark it dirty since we also free the swap
1616  * entry since a page cannot live in both the swap and page cache.
1617  *
1618  * fault_mm and fault_type are only supplied by shmem_fault:
1619  * otherwise they are NULL.
1620  */
1621 static int shmem_getpage_gfp(struct inode *inode, pgoff_t index,
1622 >-------struct page **pagep, enum sgp_type sgp, gfp_t gfp,
1623 >-------struct vm_area_struct *vma, struct vm_fault *vmf, int *fault_type)
1624 {
1625 >-------struct address_space *mapping = inode->i_mapping;
1626 >-------struct shmem_inode_info *info = SHMEM_I(inode);
1627 >-------struct shmem_sb_info *sbinfo;
1628 >-------struct mm_struct *charge_mm;
1629 >-------struct mem_cgroup *memcg;
1630 >-------struct page *page;
1631 >-------swp_entry_t swap;
1632 >-------enum sgp_type sgp_huge = sgp;
1633 >-------pgoff_t hindex = index;
1634 >-------int error;
1635 >-------int once = 0;
1636 >-------int alloced = 0;
1637 
1638 >-------if (index > (MAX_LFS_FILESIZE >> PAGE_SHIFT))
1639 >------->-------return -EFBIG;
1640 >-------if (sgp == SGP_NOHUGE || sgp == SGP_HUGE)
1641 >------->-------sgp = SGP_CACHE;
。。。
1679 >-------if (swap.val) {
1680 >------->-------/* Look it up and read it in.. */
1681 >------->-------page = lookup_swap_cache(swap, NULL, 0);
1682 >------->-------if (!page) {
1683 >------->------->-------/* Or update major stats only when swapin succeeds?? */
1684 >------->------->-------if (fault_type) {
1685 >------->------->------->-------*fault_type |= VM_FAULT_MAJOR;
1686 >------->------->------->-------count_vm_event(PGMAJFAULT);
1687 >------->------->------->-------count_memcg_event_mm(charge_mm, PGMAJFAULT);
1688 >------->------->-------}
1689 >------->------->-------/* Here we actually start the io */
1690 >------->------->-------page = shmem_swapin(swap, gfp, info, index);《---从swap 文件中读取内容，产生IO。 page会被__SetPageSwapBacked（） see, __read_swap_cache_async()<---read_swap_cache_async()<----swap_cluster_readahead()<---shmem_swapin()
1691 >------->------->-------if (!page) {
1692 >------->------->------->-------error = -ENOMEM;
1693 >------->------->------->-------goto failed;
1694 >------->------->-------}
1695 >------->-------}
1696 
1697 >------->-------/* We have to do this with page locked to prevent races */
1698 >------->-------lock_page(page);
1699 >------->-------if (!PageSwapCache(page) || page_private(page) != swap.val ||
1700 >------->-------    !shmem_confirm_swap(mapping, index, swap)) {
1701 >------->------->-------error = -EEXIST;>-------/* try again */
1702 >------->------->-------goto unlock;
1703 >------->-------}
1704 >------->-------if (!PageUptodate(page)) {
1705 >------->------->-------error = -EIO;
1706 >------->------->-------goto failed;
1707 >------->-------}
1708 >------->-------wait_on_page_writeback(page);
1709 
1710 >------->-------if (shmem_should_replace_page(page, gfp)) {
1711 >------->------->-------error = shmem_replace_page(&page, gfp, info, index);
1712 >------->------->-------if (error)
1713 >------->------->------->-------goto failed;
1714 >------->-------}
1715 
1716 >------->-------error = mem_cgroup_try_charge_delay(page, charge_mm, gfp, &memcg,
1717 >------->------->------->-------false); 《---内存计数
1718 >------->-------if (!error) {
1719 >------->------->-------error = shmem_add_to_page_cache(page, mapping, index,
1720 >------->------->------->------->------->-------swp_to_radix_entry(swap));
1721 >------->------->-------/*
1722 >------->------->------- * We already confirmed swap under page lock, and make
1723 >------->------->------- * no memory allocation here, so usually no possibility
1724 >------->------->------- * of error; but free_swap_and_cache() only trylocks a
1725 >------->------->------- * page, so it is just possible that the entry has been
1726 >------->------->------- * truncated or holepunched since swap was confirmed.
1727 >------->------->------- * shmem_undo_range() will have done some of the
1728 >------->------->------- * unaccounting, now delete_from_swap_cache() will do
1729 >------->------->------- * the rest.
1730 >------->------->------- * Reset swap.val? No, leave it so "failed" goes back to
1731 >------->------->------- * "repeat": reading a hole and writing should succeed.
1732 >------->------->------- */
1733 >------->------->-------if (error) {
1734 >------->------->------->-------mem_cgroup_cancel_charge(page, memcg, false);
1735 >------->------->------->-------delete_from_swap_cache(page);

。。。
1833 >------->-------if (error) {
1834 >------->------->-------mem_cgroup_cancel_charge(page, memcg,
1835 >------->------->------->------->-------PageTransHuge(page));
1836 >------->------->-------goto unacct;
1837 >------->-------}
1838 >------->-------mem_cgroup_commit_charge(page, memcg, false,
1839 >------->------->------->-------PageTransHuge(page));
1840 >------->-------lru_cache_add_anon(page); <---加入annon队列,算成anon memory，先放到lru_cache上，适当时机调用__pagevec_lru_add_fn（）放入正确的lru列表
1841 
1842 >------->-------spin_lock_irq(&info->lock);
1843 >------->-------info->alloced += 1 << compound_order(page);
1844 >------->-------inode->i_blocks += BLOCKS_PER_PAGE << compound_order(page);
1845 >------->-------shmem_recalc_inode(inode);
1846 >------->-------spin_unlock_irq(&info->lock);
1847 >------->-------alloced = true;
1848 
1849 >------->-------if (PageTransHuge(page) &&
1850 >------->------->------->-------DIV_ROUND_UP(i_size_read(inode), PAGE_SIZE) <
1851 >------->------->------->-------hindex + HPAGE_PMD_NR - 1) {
1852 >------->------->-------/*
1853 >------->------->------- * Part of the huge page is beyond i_size: subject
1854 >------->------->------- * to shrink under memory pressure.
1855 >------->------->------- */
1856 >------->------->-------spin_lock(&sbinfo->shrinklist_lock);
1857 >------->------->-------/*
1858 >------->------->------- * _careful to defend against unlocked access to
1859 >------->------->------- * ->shrink_list in shmem_unused_huge_shrink()
1860 >------->------->------- */
1861 >------->------->-------if (list_empty_careful(&info->shrinklist)) {
1862 >------->------->------->-------list_add_tail(&info->shrinklist,
1863 >------->------->------->------->------->-------&sbinfo->shrinklist);
1864 >------->------->------->-------sbinfo->shrinklist_len++;
1865 >------->------->-------}
1866 >------->------->-------spin_unlock(&sbinfo->shrinklist_lock);
1867 >------->-------}
。。。
}
```
```
 858 static void __pagevec_lru_add_fn(struct page *page, struct lruvec *lruvec,
 859 >------->------->------->------- void *arg)
 860 {
 861 >-------enum lru_list lru;
 862 >-------int was_unevictable = TestClearPageUnevictable(page);
 863 
 864 >-------VM_BUG_ON_PAGE(PageLRU(page), page);
 865 
 866 >-------SetPageLRU(page);
 867 >-------/*
 868 >------- * Page becomes evictable in two ways:
 869 >------- * 1) Within LRU lock [munlock_vma_pages() and __munlock_pagevec()].
 870 >------- * 2) Before acquiring LRU lock to put the page to correct LRU and then
 871 >------- *   a) do PageLRU check with lock [check_move_unevictable_pages]
 872 >------- *   b) do PageLRU check before lock [clear_page_mlock]
 873 >------- *
 874 >------- * (1) & (2a) are ok as LRU lock will serialize them. For (2b), we need
 875 >------- * following strict ordering:
 876 >------- *
 877 >------- * #0: __pagevec_lru_add_fn>---->-------#1: clear_page_mlock
 878 >------- *
 879 >------- * SetPageLRU()>>------->------->-------TestClearPageMlocked()
 880 >------- * smp_mb() // explicit ordering>-------// above provides strict
 881 >------- *>----->------->------->------->-------// ordering
 882 >------- * PageMlocked()>------->------->-------PageLRU()
 883 >------- *
 884 >------- *
 885 >------- * if '#1' does not observe setting of PG_lru by '#0' and fails
 886 >------- * isolation, the explicit barrier will make sure that page_evictable
 887 >------- * check will put the page in correct LRU. Without smp_mb(), SetPageLRU
 888 >------- * can be reordered after PageMlocked check and can make '#1' to fail
 889 >------- * the isolation of the page whose Mlocked bit is cleared (#0 is also
 890 >------- * looking at the same page) and the evictable page will be stranded
 891 >------- * in an unevictable LRU.
 892 >------- */
 893 >-------smp_mb();
 894 
 895 >-------if (page_evictable(page)) {
 896 >------->-------lru = page_lru(page);《---从page中得到lru属性
 897 >------->-------update_page_reclaim_stat(lruvec, page_is_file_cache(page),
 898 >------->------->------->------->------- PageActive(page));
 899 >------->-------if (was_unevictable)
 900 >------->------->-------count_vm_event(UNEVICTABLE_PGRESCUED);
 901 >-------} else {
 902 >------->-------lru = LRU_UNEVICTABLE;
 903 >------->-------ClearPageActive(page);
 904 >------->-------SetPageUnevictable(page);
 905 >------->-------if (!was_unevictable)
 906 >------->------->-------count_vm_event(UNEVICTABLE_PGCULLED);
 907 >-------}
 908 
 909 >-------add_page_to_lru_list(page, lruvec, lru);《---根据lru属性加入到相应的lru列表
 910 >-------trace_mm_lru_insertion(page, lru);
 911 }
 912 
 ```
 ```

 8 /**
  9  * page_is_file_cache - should the page be on a file LRU or anon LRU?
 10  * @page: the page to test
 11  *
 12  * Returns 1 if @page is page cache page backed by a regular filesystem,
 13  * or 0 if @page is anonymous, tmpfs or otherwise ram or swap backed.
 14  * Used by functions that manipulate the LRU lists, to sort a page
 15  * onto the right LRU list.
 16  *
 17  * We would like to get this info without a page flag, but the state
 18  * needs to survive until the page is last deleted from the LRU, which
 19  * could be as far down as __page_cache_release.
 20  */
 21 static inline int page_is_file_cache(struct page *page)
 22 {
 23 >-------return !PageSwapBacked(page); <---所有非SwapBacked的page都是file cache。反之就是annon page， see  page_lru_base_type().另外还有一个函数，PageAnon（），是以mapping类型决定是否annon page。
 24 }
 68 /**
 69  * page_lru_base_type - which LRU list type should a page be on?
 70  * @page: the page to test
 71  *
 72  * Used for LRU list index arithmetic.
 73  *
 74  * Returns the base LRU type - file or anon - @page should be on.
 75  */
 76 static inline enum lru_list page_lru_base_type(struct page *page)
 77 {
 78 >-------if (page_is_file_cache(page))
 79 >------->-------return LRU_INACTIVE_FILE;
 80 >-------return LRU_INACTIVE_ANON;
 81 }
377 struct page *__read_swap_cache_async(swp_entry_t entry, gfp_t gfp_mask,
378 >------->------->-------struct vm_area_struct *vma, unsigned long addr,
379 >------->------->-------bool *new_page_allocated)
380 {
381 >-------struct page *found_page, *new_page = NULL;
382 >-------struct address_space *swapper_space = swap_address_space(entry);
383 >-------int err;
384 >-------*new_page_allocated = false;
385 
386 >-------do {
387 >------->-------/*
388 >------->------- * First check the swap cache.  Since this is normally
389 >------->------- * called after lookup_swap_cache() failed, re-calling
390 >------->------- * that would confuse statistics.
391 >------->------- */
392 >------->-------found_page = find_get_page(swapper_space, swp_offset(entry));
393 >------->-------if (found_page)
394 >------->------->-------break;
395 
396 >------->-------/*
397 >------->------- * Just skip read ahead for unused swap slot.
398 >------->------- * During swap_off when swap_slot_cache is disabled,
399 >------->------- * we have to handle the race between putting
400 >------->------- * swap entry in swap cache and marking swap slot
401 >------->------- * as SWAP_HAS_CACHE.  That's done in later part of code or
402 >------->------- * else swap_off will be aborted if we return NULL.
403 >------->------- */
404 >------->-------if (!__swp_swapcount(entry) && swap_slot_cache_enabled)
405 >------->------->-------break;
406 
407 >------->-------/*
408 >------->------- * Get a new page to read into from swap.
409 >------->------- */
410 >------->-------if (!new_page) {
411 >------->------->-------new_page = alloc_page_vma(gfp_mask, vma, addr);
412 >------->------->-------if (!new_page)
413 >------->------->------->-------break;>->-------/* Out of memory */
414 >------->-------}
415 
416 >------->-------/*
417 >------->------- * call radix_tree_preload() while we can wait.
418 >------->------- */
419 >------->-------err = radix_tree_maybe_preload(gfp_mask & GFP_KERNEL);
420 >------->-------if (err)
421 >------->------->-------break;
422 423 >------->-------/*
424 >------->------- * Swap entry may have been freed since our caller observed it.
425 >------->------- */
426 >------->-------err = swapcache_prepare(entry);
427 >------->-------if (err == -EEXIST) {
428 >------->------->-------radix_tree_preload_end();
429 >------->------->-------/*
430 >------->------->------- * We might race against get_swap_page() and stumble
431 >------->------->------- * across a SWAP_HAS_CACHE swap_map entry whose page
432 >------->------->------- * has not been brought into the swapcache yet.
433 >------->------->------- */
434 >------->------->-------cond_resched();
435 >------->------->-------continue;
436 >------->-------}
437 >------->-------if (err) {>----->-------/* swp entry is obsolete ? */

437 >------->-------if (err) {>----->-------/* swp entry is obsolete ? */
438 >------->------->-------radix_tree_preload_end();
439 >------->------->-------break;
440 >------->-------}
441 
442 >------->-------/* May fail (-ENOMEM) if radix-tree node allocation failed. */
443 >------->-------__SetPageLocked(new_page);
444 >------->-------__SetPageSwapBacked(new_page); <----set page swap, here, 最终被__pagevec_lru_add_fn（）放入annon lru list
445 >------->-------err = __add_to_swap_cache(new_page, entry);
446 >------->-------if (likely(!err)) {
447 >------->------->-------radix_tree_preload_end();
448 >------->------->-------/*
449 >------->------->------- * Initiate read into locked page and return.
450 >------->------->------- */
451 >------->------->-------lru_cache_add_anon(new_page);
452 >------->------->-------*new_page_allocated = true;
453 >------->------->-------return new_page;
454 >------->-------}
455 >------->-------radix_tree_preload_end();
456 >------->-------__ClearPageLocked(new_page);
457 >------->-------/*
458 >------->------- * add_to_swap_cache() doesn't return -EEXIST, so we can safely
459 >------->------- * clear SWAP_HAS_CACHE flag.
460 >------->------- */
461 >------->-------put_swap_page(new_page, entry);
462 >-------} while (err != -ENOMEM);
463 
464 >-------if (new_page)
465 >------->-------put_page(new_page);
466 >-------return found_page;
467 }
```
```
420 static __always_inline int PageAnon(struct page *page)
421 {
422 >-------page = compound_head(page); 
423 >-------return ((unsigned long)page->mapping & PAGE_MAPPING_ANON) != 0;
424 }
```
