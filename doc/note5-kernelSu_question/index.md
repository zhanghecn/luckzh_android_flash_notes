# android-pixel4a-刷机系列-(5)kernelsu编译问题解决及使用

上一节编译的``kernelSu``有点问题,本次就进行修复重新编译

## 重编译

首先我想到的是上一篇 出现 ``savedefconfig`` 不匹配的问题

```
....
--- private/msm-google/arch/arm64/configs/sunfish_defconfig	2023-06-27 15:56:28.068070234 +0800
+++ ~/aosp/android-kernel/out/android-msm-pixel-4.14/private/msm-google/defconfig	2023-06-27 22:37:59.857566122 +0800
@@ -685,7 +685,6 @@
 CONFIG_QUOTA_NETLINK_INTERFACE=y
 CONFIG_QFMT_V2=y
 CONFIG_FUSE_FS=y
-CONFIG_OVERLAY_FS=y
 CONFIG_INCREMENTAL_FS=m
 CONFIG_VFAT_FS=y
 CONFIG_TMPFS_POSIX_ACL=y
++ RES=1
++ '[' 1 -ne 0 ']'
++ echo ERROR: savedefconfig does not match private/msm-google/arch/arm64/configs/sunfish_defconfig
ERROR: savedefconfig does not match private/msm-google/arch/arm64/configs/sunfish_defconfig
++ return 1

```

之前我们的解决方案是 注释掉 ``KernelSu`` 的 ``Kconfig`` 中的 ``select OVERLAY_FS`` 选项
```
menu "KernelSU"

config KSU
	tristate "KernelSU function support"
	#select OVERLAY_FS
	default y
	help
	Enable kernel-level root privileges on Android System.
```    

这样确实 ``ok`` 了。但总感觉这样不是正确的解决办法。
所以我通过查看 其他人的仓库修改

![Alt text](image01.png)

确认了几个修改位置。

### 去掉 check_defconfig 

在 ``build/build.sh`` 脚本中,我发现了这样一段代码
```
if [ -z "${SKIP_DEFCONFIG}" ] ; then
set -x
(cd ${KERNEL_DIR} && make "${TOOL_ARGS[@]}" O=${OUT_DIR} ${MAKE_ARGS} ${DEFCONFIG})
set +x

if [ -n "${POST_DEFCONFIG_CMDS}" ]; then
  echo "========================================================"
  echo " Running pre-make command(s):"
  set -x
  eval ${POST_DEFCONFIG_CMDS}
  set +x
fi
fi
```

重点看 ``POST_DEFCONFIG_CMDS`` 这会在调用 ``make xx  xxx_defconfig`` 生成``.config``后调用一些命令。

我们看下 ``private/msm-google/build.config`` 文件
```
KERNEL_DIR=private/msm-google
. ${ROOT_DIR}/${KERNEL_DIR}/build.config.common.clang
POST_DEFCONFIG_CMDS="check_defconfig"
```

发现他调用了 ``check_defconfig``方法,这个方法在哪里呢？

回到 ``build`` 目录下你会发现一个叫 ``_setup_env.sh``的文件
```
echo
echo "PATH=${PATH}"
echo

# verifies that defconfig matches the DEFCONFIG
function check_defconfig() {
    (cd ${OUT_DIR} && \
     make "${TOOL_ARGS[@]}" O=${OUT_DIR} savedefconfig)
    [ "$ARCH" = "x86_64" -o "$ARCH" = "i386" ] && local ARCH=x86
    echo Verifying that savedefconfig matches ${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG}
    RES=0
    diff -u ${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG} ${OUT_DIR}/defconfig ||
      RES=$?
    if [ ${RES} -ne 0 ]; then
        echo ERROR: savedefconfig does not match ${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG}
    fi
    return ${RES}
}

```

它里面就有 ``check_defconfig`` 方法,可以看到它通过 ``make ... savedefconfig`` 从``.config``提取的 ``defconfig``。
并使用 ``diff``进行比较差异。
这就难受了,因为我修改 ``arch/arm64/configs/xxx_defconfig``后。``make ... savedfconfig`` 从 ``.config``总是提取的 ``defconfig``成我未修改前的样子,**百思不得其解** **百思不得其解** **百思不得其解** 

那好,砸门去掉这个。只不过不是去掉 ``build.config``里的。

而是去掉 ``build_sunfish.sh``里的

![Alt text](image02.png)

它里面的配置指向了 ``build.config.sunfish_no-cfi``,所以我们改这个
```
BUILD_CONFIG=private/msm-google/build.config.sunfish_no-cfi build/build.sh "$@"
```

改成如下
```
KERNEL_DIR=private/msm-google
. ${ROOT_DIR}/${KERNEL_DIR}/build.config.sunfish.common.clang
#POST_DEFCONFIG_CMDS="check_defconfig && update_nocfi_config"
POST_DEFCONFIG_CMDS="update_nocfi_config"

function update_nocfi_config() {
  # Disable clang-specific options
  ${KERNEL_DIR}/scripts/config --file ${OUT_DIR}/.config \
    -d LTO \
    -d LTO_CLANG \
    -d CFI \
    -d CFI_PERMISSIVE \
    -d CFI_CLANG
  (cd ${OUT_DIR} && \
   make ${CC_LD_ARG} O=${OUT_DIR} olddefconfig)
}
```

只不过构建的时候不是调用 ``build/build.sh`` 了,而是直接调用 ``build_sunfish.sh``

### kprobe 配置
kernelSu 通过 kprobe 去 hook 内核 实现的功能。所以我们得让编译的内核支持 ``kprobe``
在 ``arch/arm64/configs/xxx_defconfig``添加如下配置
```
CONFIG_KPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_KPROBE_EVENTS=y
```

![Alt text](image03.png)

### 构建时候强调点问题
如果发现你已经改的很乱了,然后编译出现其他报错。

那么请恢复之前可以构建的时候,在重新 拉 ``kernelsu``的代码

```
# 只删除代码,不删除``repo``仓库
rm -rf !(".repo")
# 重新同步
repo sync

cd private/msm-google

curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
```

然后按照之前的配置重新配一遍安装即可

## kernelsu 使用

按照作者的介绍,**kernelSu** 除了可以直接给 **root** 外,还可以更细腻的分配权限。

当然官网没有给出详细的使用,我是从作者的 ``B站`` 看到的，搜索 ``术哥喜欢皮卡丘``您应该可以找到。

![Alt text](image04.png)


### kernelsu模块

kernelsu 使用的 ``Magisk`` 的 ``BusyBox`` 和 ``overlayfs mount``机制 完成和 ``magisk``相同的 模块功能。
所以理论上,大部分``magisk``模块都可以适用在 ``kernelsu``上面

当然与 ``magisk`` 模块也有差异
具体参考: [https://kernelsu.org/zh_CN/guide/difference-with-magisk.html](https://kernelsu.org/zh_CN/guide/difference-with-magisk.html)

``kernelsu``不像 magisk 那样自动携带的 ``zygisk``,所以要提供 ``zygisk``的支持,需要使用到``ZygiskOnKernelSu``的模块。

模块地址在:[https://github.com/Dr-TSNG/ZygiskOnKernelSU](https://github.com/Dr-TSNG/ZygiskOnKernelSU)


首先我们将``ZygiskOnKernelSu``进行下载:
```
wget “https://github.com/Dr-TSNG/ZygiskOnKernelSU/releases/download/v4-0.7.1/Zygisk-on-KernelSU-v4-0.7.1-89-release.zip” -O "Zygisk-on-KernelSU-v4-0.7.1-89-release.zip"

adb push .\Zygisk-on-KernelSU-v4-0.7.1-89-release.zip /sdcard/
```

随后通过``kernelsu app``进行安装

安装完后,在安装``Zygisk - Lsposed``,并进行查看

![Alt text](image05.png)

![Alt text](image06.png)

但此时 ``zygisk``暴露出来了,所以我们还需要安装``shamiko``

```
wget "https://github.com/LSPosed/LSPosed.github.io/releases/download/shamiko-174/Shamiko-v0.7.3-174-release.zip" -O "Shamiko-v0.7.3-174-release.zip"

adb push Shamiko-v0.7.3-174-release.zip /sdcard/
```

查看下 ``momo``

![Alt text](image07.png)

**kernelsu 的 root 未检查到,zygisk 也未检测到**

但是因为现在的``aosp`` 采用的 ``userdebug`` 构建的,并且使用``adb remount``挂载了分区,所以还是被检测到了异常。但这些异常并不是
``kernelsu``被检测到了。

问了下``debug_cat``,说要解决的话我们得修改 ``aosp``的代码 或者换``pixel6``一劳永逸,将构建的``userdebug``伪造成``user``,并且需要把指纹签名重弄一遍。
我看了半天,再三思索,决定放弃,因为有点麻烦。

所以下一节我打算直接采用 官方出厂镜像 覆盖``kernel启动镜像``重试一遍。

也打算结束此次教程了。

