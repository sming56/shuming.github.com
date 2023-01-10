# RCU实现
## rcu_read_lock
 830 static inline void rcu_read_lock(void)
 831 {
 832 >-------__rcu_read_lock();<---非PREEMT版就是关PREEMT, PREEMT版就是空
 833 >-------__acquire(RCU); <---扩展为空或者是一个编译器标记(做锁检查）
 834 >-------rcu_lock_acquire(&rcu_lock_map);
 835 >-------rcu_lockdep_assert(rcu_is_watching(),
 836 >------->------->-------   "rcu_read_lock() used illegally while idle");
 837 }

总之，在运行环境下这个函数基本为空，最多就是关PREEMT
