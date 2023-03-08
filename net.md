## 4.18内核ep_poll函数调用驱动回调函数可能导致CPU升高
```
1735  * Returns: Returns the number of ready events which have been fetched, or an
1736  *          error code, in case of error.
1737  */
1738 static int ep_poll(struct eventpoll *ep, struct epoll_event __user *events,
1739 >------->-------   int maxevents, long timeout)
1740 {
1741 >-------int res = 0, eavail, timed_out = 0;
1742 >-------unsigned long flags;
1743 >-------u64 slack = 0;
1744 >-------wait_queue_entry_t wait;
1745 >-------ktime_t expires, *to = NULL;
1746 
1747 >-------if (timeout > 0) {
1748 >------->-------struct timespec64 end_time = ep_set_mstimeout(timeout);
1749 
1750 >------->-------slack = select_estimate_accuracy(&end_time);
1751 >------->-------to = &expires;
1752 >------->-------*to = timespec64_to_ktime(end_time);
1753 >-------} else if (timeout == 0) {
1754 >------->-------/*
1755 >------->------- * Avoid the unnecessary trip to the wait queue loop, if the
1756 >------->------- * caller specified a non blocking operation.
1757 >------->------- */
1758 >------->-------timed_out = 1;
1759 >------->-------spin_lock_irqsave(&ep->lock, flags);
1760 >------->-------goto check_events;
1761 >-------}
1762 
1763 fetch_events:
1764 
1765 >-------if (!ep_events_available(ep))
1766 >------->-------ep_busy_loop(ep, timed_out); <---调用驱动回调函数比如mlx5e_napi_poll() , 设置/proc/sys/net/core/busy_poll 为0可关闭
1767 
1768 >-------spin_lock_irqsave(&ep->lock, flags);
1769 
1770 >-------if (!ep_events_available(ep)) {
1771 >------->-------/*
1772 >------->------- * Busy poll timed out.  Drop NAPI ID for now, we can add
1773 >------->------- * it back in when we have moved a socket with a valid NAPI
1774 >------->------- * ID onto the ready list.
1775 >------->------- */
1776 >------->-------ep_reset_busy_poll_napi_id(ep);
1777 
1778 >------->-------/*
1779 >------->------- * We don't have any available event to return to the caller.
1780 >------->------- * We need to sleep here, and we will be wake up by
1781 >------->------- * ep_poll_callback() when events will become available.
1782 >------->------- */
```

