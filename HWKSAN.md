# HWKSAN 
## memory tagging extension(MTE) support in ARM64 v8.5+
'''
pointer tags(key)
ARM64 v8.5+ support to use the high four bits(56 ~ 59) to store pointer tags

memory tags(lock)
ARM64 v8.5+  support to store the memory tags by hardware.  There are shadow memory managed by hardware to store the memory tags. There is a specific machine instruction to store the memory tags.

key/lock comparision when load/store
When the load/sore happens, the hardware will check if the key and lock is matched.

key's collision
Because there the key value only have four bits, there is 1/16 possibility that two different pointers collide on the key. For example, a pointer p1 is 0xfdffffff8000000, the key is 'd' and the real
address is 0xffffff8000000. Then p1 is freed and another pointer p2 is allocated with 0xffffff8000000, and the key is also 'd'. Then there is no way to detect memory corruption when freed p1 is accessed.
'''
