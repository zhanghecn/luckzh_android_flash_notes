# kernelSu 内核编译及刷入

你可以参考 ``debug选手``大佬的 ``Pixel3编译的Kernel SU 内核``。
地址来源: ``http://www.debuglive.cn/article/1091666763961073664``

我也是基于 ``debug_cat``上进行 内核的修改。 不过没有 **B站详细** 


## kernelSu 简介
KernelSU 是 Android GKI 设备的 root 解决方案，它工作在内核模式，并直接在内核空间中为用户空间应用程序授予 root 权限。

KernelSU 的主要特点是它是基于内核的。 KernelSU 运行在内核空间， 所以它可以提供我们以前从未有过的内核接口。 例如，我们可以在内核模式下为任何进程添加硬件断点；我们可以在任何进程的物理内存中访问，而无人知晓；我们可以在内核空间拦截任何系统调用; 等等。
KernelSU 还提供了一个基于 overlayfs 的模块系统，允许您加载自定义插件到系统中。它还提供了一种修改 /system 分区中文件的机制。

参考官方文档: **https://kernelsu.org/zh_CN/guide/what-is-kernelsu.html**

## 安装kernelSu

> 以下是基于  GKI 内核
>>关于安装kernelSu 您可以到他的**github release** 中下载对应内核的 **boot.img** 进行刷入(建议用``AnyKernel3``刷机包)。
并下载 **kernelsu app** 进行管理。 这个 app





