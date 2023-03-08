##函数指针汇编
```
/usr/src/debug/kernel-5.10.0-60.18.0.mt20230307.506.x86_64/linux-5.10.0-60.18.0.mt20230307.506.x86_64/drivers/video/fbdev/core/softcursor.c: 74
0xffffffffb9a8a360 <soft_cursor+400>:   mov    %rbp,%rsi
0xffffffffb9a8a363 <soft_cursor+403>:   mov    %r12,%rdi
0xffffffffb9a8a366 <soft_cursor+406>:   mov    0x4e0(%r12),%rax
0xffffffffb9a8a36e <soft_cursor+414>:   mov    0x68(%rax),%rax
0xffffffffb9a8a372 <soft_cursor+418>:   callq  0xffffffffba202520 <__x86_indirect_thunk_rax>

  	info->fbops->fb_imageblit(info, image); //对应上面的汇编代码

crash> struct fb_info.fbops -o -x
struct fb_info {
  [0x4e0] const struct fb_ops *fbops;
}
crash> struct fb_ops.fb_imageblit -o -x
struct fb_ops {
  [0x68] void (*fb_imageblit)(struct fb_info *, const struct fb_image *);
}
crash>
crash> dis __x86_indirect_thunk_rax
0xffffffffba202520 <__x86_indirect_thunk_rax>:  jmpq   *%rax
0xffffffffba202522 <__x86_indirect_thunk_rax+2>:        nop
0xffffffffba202523 <__x86_indirect_thunk_rax+3>:        nop
0xffffffffba202524 <__x86_indirect_thunk_rax+4>:        nop1

```
