# android-pixel4a-刷机系列-(3)内核下载并编译

因为我是初学者,踩的坑比我预计的要多,试试难预料呀。

各种错误,无处下手,一度想放弃。越往后,能查到的资料越少,是我搜索的关键词不对吗？

与其说我这是个教程,不如叫做``踩坑笔记``


本次资料参考来源: [https://source.android.google.cn/docs/setup/build/building-kernels?hl=zh-cn](https://source.android.google.cn/docs/setup/build/building-kernels?hl=zh-cn)

以及 [http://www.debuglive.cn/article/1074036099963158528](http://www.debuglive.cn/article/1074036099963158528)

在aosp 源码中的内核是已经编译好

而当要修改内核的时候,就得对源码下手了,所以我们得从源码编译内核。

## 下载内核

```
mkdir android-kernel && cd android-kernel

# 换成中科大的
repo init -u https://mirrors.ustc.edu.cn/aosp/kernel/manifest.git/ -b android-msm-sunfish-4.14-android13-qpr2

# 同步代码
repo sync
```
关于 ``-b``分支的选择

| 设备                                                     | AOSP 树中的二进制文件路径       | Repo 分支                               |
| -------------------------------------------------------- | ------------------------------- | --------------------------------------- |
| Pixel 7 (panther)Pixel 7 Pro (cheetah)                   | device/google/pantah-kernel     | android-gs-pantah-5.10-android13-qpr2   |
| Pixel 6a (bluejay)                                       | device/google/bluejay-kernel    | android-gs-bluejay-5.10-android13-qpr2  |
| Pixel 6 (oriole)Pixel 6 Pro (raven)                      | device/google/raviole-kernel    | android-gs-raviole-5.10-android13-qpr2  |
| Pixel 5a (barbet)Pixel 5 (redfin)Pixel 4a (5G) (bramble) | device/google/redbull-kernel    | android-msm-redbull-4.19-android13-qpr2 |
| Pixel 4a (sunfish)                                       | device/google/sunfish-kernel    | android-msm-sunfish-4.14-android13-qpr2 |
| Pixel 4 (flame)Pixel 4 XL (coral)                        | device/google/coral-kernel      | android-msm-coral-4.14-android13        |
| Pixel 3a (sargo)Pixel 3a XL (bonito)                     | device/google/bonito-kernel     | android-msm-bonito-4.9-android12L       |
| Pixel 3 (blueline)Pixel 3 XL (crosshatch)                | device/google/crosshatch-kernel | android-msm-crosshatch-4.9-android12    |
| Pixel 2 (walleye)Pixel 2 XL (taimen)                     | device/google/wahoo-kernel      | android-msm-wahoo-4.4-android10-qpr3    |
| Pixel (sailfish)Pixel XL (marlin)                        | device/google/marlin-kernel     | android-msm-marlin-3.18-pie-qpr2        |
| Hikey960                                                 | device/linaro/hikey-kernel      | hikey-linaro-android-4.14               |


## 构建内核

构建内核直接执行 ``build/build.sh``的脚本即可

构建出来的二进制文件在 ``out/**BRANCH**/dist``  中

比如我的是在 ``android-kernel/out/android-msm-pixel-4.14/dist``

编译时,可能会出现的错误及解决方案
```
​# 出现 openssl/bio.h: No such file or directory​​ 安装下面依赖
sudo apt install libssl-dev
```

### 参与 aosp 构建

由于内核最终会构建在 ``boot.img``里,所以我们只需要运行``make bootimage`` 然后再构建 ``boot`` 分区的时候指定下我们构建内核的位置。 通常这个文件是 ``Image.lz4-dtb``

```
cd aosp

source build/envsetup.sh
lunch aosp_sunfish-user
# 注意 DIST_DIR先写你构建内核的位置
# 比如我的位置是 ~/aosp/android-kernel/out/android-msm-pixel-4.14/dist
# export TARGET_PREBUILT_KERNEL=~/aosp/android-kernel/out/android-msm-pixel-4.14/dist/Image.lz4-dtb
export TARGET_PREBUILT_KERNEL=DIST_DIR/Image.lz4-dtb
# 只构建 boot
make bootimage
```

接下来只需要刷入``boot.img`` 即可。
```
# 注意最后面的 sunfish 这是pixel4a 的
cd out/target/product/sunfish
adb reboot bootloader
# 可以临时测试一下,重启失效
fastboot boot boot.img
# 测试没问题进行刷入
fastboot flash boot boot.img
fastboot reboot
```

### 内核模块

刷入后并没有成功开机,卡在了启动界面

结合 **debug_cat** 的文章:``http://www.debuglive.cn/article/1074036099963158528``

以及 **chatGpt** 的回答
```
如果你只设置 export TARGET_PREBUILT_KERNEL=DIST_DIR/Image.lz4，而没有复制 .ko 文件，那么编译的 boot.img 可能无法正常加载缺少的内核模块，导致某些功能无法正常工作或设备无法启动。

.ko 文件包含了内核模块的代码和数据，这些模块提供了设备的特定功能或驱动。如果缺少关键的内核模块，设备可能会遇到硬件兼容性问题，或者某些功能无法正常运行。

因此，为了确保编译的 boot.img 可以正常刷入并正确工作，建议将相应的 .ko 文件复制到合适的位置，并在设备树配置中添加正确的模块路径。

只设置 TARGET_PREBUILT_KERNEL 变量来指定 Image.lz4 文件是为了替换默认的内核映像文件。但仍需要确保内核映像文件和相关的内核模块是匹配的，以保证设备的正常运行。
```

大概清楚了一些东西

1. Image.lz4和Image.lz4-dtb 貌似是不同的压缩格式的内核启动镜像
2. .ko文件是一些内核模块,如果不匹配就会无法开机,或者触屏 wifi 失效等情况

更多内核模块的说明参考:``https://source.android.com/docs/core/architecture/kernel/loadable-kernel-modules?hl=zh-cn``


所以我们还需要把 ``.ko`` 集成到 ``vendor.img``里面去。
但是``vendor`` 是在上一章刷机中是通过``https://developers.google.com/android/drivers?hl=zh-cn`` 下载的特定官方的 pixel 厂商的驱动二进制文件里来的,这并不是开源,所以没办法直接集成打包进去。

我们得直接通过 ``adb``将 .ko 的内核模块全部 ``push`` 到 `` /vendor/lib/modules``中
```
# 禁用 dm-verity
adb root
adb disable-verity
adb reboot
# 重新以 可读可写的 形式挂载分区
adb root
adb remount 
# push 到 vendor 分区对应的 内核模块的目录
cd ~/aosp/android-kernel/out/android-msm-pixel-4.14/dist/
adb push *.ko /vendor/lib/modules
adb reboot

# 建议之后重新开启dm-verity
adb enable-verity
```

如果lunch 选择的构建类型不是 userdebug 而是 user

那么您应该又踩坑了(好吧,这是我踩的坑),  ``adb remount`` 只有在 **userdebug** 下才能运行 。这样您才可以使用 ``overlayfs``重新挂载成可写入的分区。

参考文档: [https://android.googlesource.com/platform/system/core/+/a9a3b73163fda5abf237cc0f0cee97ff33e6254d/fs_mgr/README.overlayfs.md](https://android.googlesource.com/platform/system/core/+/a9a3b73163fda5abf237cc0f0cee97ff33e6254d/fs_mgr/README.overlayfs.md)

因为本身 ``vendor``分区是不可写的,想刷入 **.ko** 内核模块,必须用 ``remount`` 挂载成可写的

**(原谅我并不是一个好人)**

>理论上只要能解压vendor.img 并且可以重新修改打包vendor.img,那么就不需要采用overlayfs挂载的方式进行覆盖.ko内核模块。但是目前来说我并没有找到关于修改vendor分区的工具以及资料。

>不过貌似可以通过编写magisk模块,完成overlayfs 挂载 vendor 的操作

下面是关于重新构建``userdebug``版本的操作:
```
source build/envsetup.sh

lunch 37

    You're building on Linux

    Lunch menu .. Here are the common combinations:
        ....
        1.  aosp_redfin-userdebug
        2.  aosp_redfin_car-userdebug
        3.  aosp_redfin_vf-userdebug
        4.  aosp_slider-userdebug
        5.  aosp_sunfish-userdebug
        6.  aosp_sunfish_car-userdebug
        7.  aosp_trout_arm64-userdebug
        8.  aosp_trout_x86-userdebug
        9.  aosp_whitefin-userdebug

m -j1

!!!!如果出现闪退或者报错,使用 make clean 后在重新构建
```
接下来重复之前的操作即可

### 确认内核版本

刷进去后 通过下面命令查看当前内核版本
```
adb shell
# 您也可以通过 uname -a 查看内核版本信息
cat /proc/version
Linux version 4.14.295 (xxx@xxxx-virtual-machine) (Android (7284624, based on r416183b) clang version 12.0.5 (https://android.googlesource.com/toolchain/llvm-project c935d99d7cf2016289302412d708641d52d2f7ee), LLD 12.0.5 (/buildbot/src/android/llvm-toolchain/out/llvm-project/lld c935d99d7cf2016289302412d708641d52d2f7ee)) #1 repo:android-msm-sunfish-4.14-android13-qpr2 SMP PREEMPT Mon 
```


查看编译的``Image.lz4-dtb``内核启动文件
```
grep -a 'Linux version' Image.lz4-dtb

"initcall_debugLinux version 4.14.295 
```
![Alt text](image01.png)

内核版本算是刷进去了


