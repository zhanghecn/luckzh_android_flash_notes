
# $0 filename 
#readlink : absolute path
export ROOT_DIR=$(readlink -f $(dirname $0)/..)

source "${ROOT_DIR}/build/_setup_env.sh"
export MODULES_STAGING_DIR=$(readlink -m ${COMMON_OUT_DIR}/staging)


export VENDOR_RAMDISK_BINARY=/home/zhangxuan/Desktop/android_image_kitchen/AIK-Linux/split_img/boot.img-ramdisk.cpio.gz
export BUILD_BOOT_IMG=1
export BASE_ADDRESS=0x00000000
export PAGE_SIZE=4096
export KERNEL_CMDLINE="console=ttyMSM0,115200n8 androidboot.console=ttyMSM0 printk.devkmsg=on \
msm_rtb.filter=0x237 ehci-hcd.park=3 service_locator.enable=1 androidboot.memcg=1 cgroup.memory=nokmem \
lpm_levels.sleep_disabled=1 usbcore.autosuspend=7 loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 \ 
swiotlb=1 androidboot.boot_devices=soc/1d84000.ufshc cgroup_disable=pressure buildvariant=user"
export KERNEL_BINARY="Image.lz4"
export BOOT_IMAGE_HEADER_VERSION=2

echo "=============================="
echo "env variables:"
echo "ROOT_DIR :${ROOT_DIR} "
echo "COMMON_OUT_DIR :${COMMON_OUT_DIR} "
echo "MODULES_STAGING_DIR :${MODULES_STAGING_DIR} "
echo "OUT_DIR :${OUT_DIR} "
echo "DIST_DIR :${DIST_DIR} "
echo "BUILD_BOOT_IMG :${BUILD_BOOT_IMG} "
echo "BASE_ADDRESS :${BASE_ADDRESS} "
echo "PAGE_SIZE :${PAGE_SIZE} "
echo "KERNEL_CMDLINE :${KERNEL_CMDLINE} "
echo "VENDOR_RAMDISK_BINARY :${VENDOR_RAMDISK_BINARY} "
echo "KERNEL_BINARY :${KERNEL_BINARY} "
echo "BOOT_IMAGE_HEADER_VERSION :${BOOT_IMAGE_HEADER_VERSION} "

# 是否构建 boot.img
if [ ! -z "${BUILD_BOOT_IMG}" ] ; then

  # mkbootimg 参数列表
	MKBOOTIMG_ARGS=()

  # 基础参数
	if [ -n  "${BASE_ADDRESS}" ]; then
		MKBOOTIMG_ARGS+=("--base" "${BASE_ADDRESS}")
	fi
	if [ -n  "${PAGE_SIZE}" ]; then
		MKBOOTIMG_ARGS+=("--pagesize" "${PAGE_SIZE}")
	fi
	if [ -n "${KERNEL_CMDLINE}" ]; then
		MKBOOTIMG_ARGS+=("--cmdline" "${KERNEL_CMDLINE}")
	fi

  # 设置 --dtb 为内核构建出来的
	DTB_FILE_LIST=$(find ${DIST_DIR} -name "*.dtb")
	if [ -z "${DTB_FILE_LIST}" ]; then
		if [ -z "${SKIP_VENDOR_BOOT}" ]; then
			echo "No *.dtb files found in ${DIST_DIR}"
			exit 1
		fi
	else
		cat $DTB_FILE_LIST > ${DIST_DIR}/dtb.img
		MKBOOTIMG_ARGS+=("--dtb" "${DIST_DIR}/dtb.img")
	fi

  # VENDOR_RAMDISK_BINARY 为 boot 通用 ramdisk 的路径
  # initramfs.cpio 为 内核构建出来的 供应商 ramdisk
	set -x
	MKBOOTIMG_RAMDISKS=()
	for ramdisk in ${VENDOR_RAMDISK_BINARY} \
		       "${MODULES_STAGING_DIR}/initramfs.cpio"; do
		if [ -f "${DIST_DIR}/${ramdisk}" ]; then
			MKBOOTIMG_RAMDISKS+=("${DIST_DIR}/${ramdisk}")
		else
			if [ -f "${ramdisk}" ]; then
				MKBOOTIMG_RAMDISKS+=("${ramdisk}")
			fi
		fi
	done

  echo "MKBOOTIMG_RAMDISKS len:${#MKBOOTIMG_RAMDISKS[@]} \
    MKBOOTIMG_RAMDISKS[*]:${MKBOOTIMG_RAMDISKS[*]}
    "

  # 将 boot ramdisk 和 vendor ramdisk 尝试解压 gzip 提取 cpio归档 
	for ((i=0; i<"${#MKBOOTIMG_RAMDISKS[@]}"; i++)); do
		CPIO_NAME="$(mktemp -t build.sh.ramdisk.XXXXXXXX)"
		if gzip -cd "${MKBOOTIMG_RAMDISKS[$i]}" 2>/dev/null > ${CPIO_NAME}; then
			MKBOOTIMG_RAMDISKS[$i]=${CPIO_NAME}
		else
			rm -f ${CPIO_NAME}
		fi
	done

  # 将  boot ramdisk 和 vendor ramdisk 合并成一个 ramdisk
  rm -f ${DIST_DIR}/ramdisk.gz
	if [ "${#MKBOOTIMG_RAMDISKS[@]}" -gt 0 ]; then
		cat ${MKBOOTIMG_RAMDISKS[*]} | gzip - > ${DIST_DIR}/ramdisk.gz
	elif [ -z "${SKIP_VENDOR_BOOT}" ]; then
		echo "No ramdisk found. Please provide a GKI and/or a vendor ramdisk."
		exit 1
	fi
	set -x

  # mkbootimg 
	if [ -z "${MKBOOTIMG_PATH}" ]; then
		MKBOOTIMG_PATH="tools/mkbootimg/mkbootimg.py"
	fi
	if [ ! -f "$MKBOOTIMG_PATH" ]; then
		echo "mkbootimg.py script not found. MKBOOTIMG_PATH = $MKBOOTIMG_PATH"
		exit 1
	fi

	if [ ! -f "${DIST_DIR}/$KERNEL_BINARY" ]; then
		echo "kernel binary(KERNEL_BINARY = $KERNEL_BINARY) not present in ${DIST_DIR}"
		exit 1
	fi

	if [ "${BOOT_IMAGE_HEADER_VERSION}" -eq "3" ]; then
		if [ -f "${GKI_RAMDISK_PREBUILT_BINARY}" ]; then
			MKBOOTIMG_ARGS+=("--ramdisk" "${GKI_RAMDISK_PREBUILT_BINARY}")
		fi

		if [ -z "${SKIP_VENDOR_BOOT}" ]; then
			MKBOOTIMG_ARGS+=("--vendor_boot" "${DIST_DIR}/vendor_boot.img" \
				"--vendor_ramdisk" "${DIST_DIR}/ramdisk.gz")
			if [ -n "${KERNEL_VENDOR_CMDLINE}" ]; then
				MKBOOTIMG_ARGS+=("--vendor_cmdline" "${KERNEL_VENDOR_CMDLINE}")
			fi
		fi
	else
		MKBOOTIMG_ARGS+=("--ramdisk" "${DIST_DIR}/ramdisk.gz")
	fi

	set -x
	python "$MKBOOTIMG_PATH" --kernel "${DIST_DIR}/${KERNEL_BINARY}" \
		--header_version "${BOOT_IMAGE_HEADER_VERSION}" \
		"${MKBOOTIMG_ARGS[@]}" -o "${DIST_DIR}/boot.img"
	set +x

	echo "boot image created at ${DIST_DIR}/boot.img"
fi