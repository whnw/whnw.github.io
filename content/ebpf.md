# qemu运行交叉编译的libbpf_bootstrap程序

使用的虚拟机Ubuntu20.04，实验的内核版本5.15.1

## 1. 编译内核

[编译并运行内核](https://github.com/snrainw/rwk.github.io/blob/main/test.md)

为了运行example/c下的程序，还要开启一些内核选项，在命令`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig`后执行`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig` 

* BPF系列

  * CONFIG_BPF=y
    CONFIG_HAVE_EBPF_JIT=y
    CONFIG_ARCH_WANT_DEFAULT_BPF_JIT=y
    CONFIG_BPF_SYSCALL=y
    CONFIG_BPF_JIT=y
    CONFIG_BPF_JIT_ALWAYS_ON=y
    CONFIG_BPF_JIT_DEFAULT_ON=y

    CONFIG_USERMODE_DRIVER=y
    CONFIG_BPF_PRELOAD=y
    CONFIG_BPF_PRELOAD_UMD=y

* FTRACE系列

  * CONFIG_FTRACE=y

    CONFIG_FUNCTION_TRACER=y
    CONFIG_FUNCTION_GRAPH_TRACER=y
    CONFIG_DYNAMIC_FTRACE=y
    CONFIG_DYNAMIC_FTRACE_WITH_REGS=y
    CONFIG_FUNCTION_PROFILER=y
    CONFIG_STACK_TRACER=y

    CONFIG_SCHED_TRACER=y

    CONFIG_FTRACE_SYSCALLS=y

* BTF系列

  * CONFIG_DEBUG_INFO_BTF=y
    CONFIG_PAHOLE_HAS_SPLIT_BTF=y
    CONFIG_DEBUG_INFO_BTF_MODULES=y

另外kprobe相关的也勾选上 CONFIG_KPROBES=y, CONFIG_HAVE_KPROBES=y, CONFIG_KPROBE_EVENTS=y

多勾选几个无伤大雅，然后再编译一遍内核。快速定位到子菜单：进入menuconfig界面后按`/`，然后把选项粘贴进去，按下数字如1进行跳转，后面就可以一个个按`y`进行勾选了。

[或者直接复制.config到kernel目录](https://github.com/snrainw/rwk.github.io/blob/main/.config)

## 2. 编译example/c下的程序

[见链接](https://github.com/snrainw/rwk.github.io/blob/main/tmp.md)

## 3. 运行

在执行`sudo sh run.sh`之前先进行如下操作

* 新编译的内核Image复制到run.sh同目录
* example/c下程序如bootstrap复制到_install/bin下
* 重新制作initramfs

运行结果如下（还是有一些错误打印，不过可以成功运行了）

```
~ # bootstrap &
~ # ls
13:34:58 EXEC  ls               127     122     /bin/ls
bin      etc      lib      proc     sbin     tmp
dev      init     linuxrc  root     sys      usr
13:34:58 EXIT  ls               127     122     [0] (38ms)
~ #
```

