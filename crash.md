如何用crash打印结构里的可变数组
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


