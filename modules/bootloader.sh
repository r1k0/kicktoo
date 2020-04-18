map_device_to_grub_device() {
    local device=$1
    if [ ! -f "${chroot_dir}/boot/grub/device.map" ]; then
        debug map_device_to_grub_device "device.map doesn't exist...creating"
        spawn_chroot "echo quit | /sbin/grub --batch --no-floppy --device-map=/boot/grub/device.map >/dev/null 2>&1" || die "Could not create grub device map"
    fi
    grep "${device}\$" "${chroot_dir}"/boot/grub/device.map | awk '{ print $1; }' | sed -e 's:[()]::g'
}

get_kernel_and_initrd() {
    local kernels=() initrd kpreffixes rpreffixes kversion suffixes
    kpreffixes=("vmlinuz" "kernel-genkernel" "kernel" "vmlinux")
    rpreffixes=("initramfs" "initrd")
    suffixes=(".img" ".cpio" ".gz" ".bz2" ".lzma" ".xz" ".lzo" ".lz4")
    for kpreffix in "${kpreffixes[@]}"; do
        if find "${chroot_dir}"/boot/"${kpreffix}"-* >/dev/null 2>&1; then
            for kernel in "${chroot_dir}"/boot/"${kpreffix}"-*; do
                basekernel=$(basename "${kernel}")
                kversion=$(echo "${basekernel}" | sed -e "s/^${kpreffix}-//" -e "s/.old//")
                for suffix in "${suffixes[@]}"; do
                    kversion="${kversion/${suffix}/}"
                done
                found=0
                for rpreffix in "${rpreffixes[@]}"; do
                    if find "/boot/${rpreffix}-${kversion}"* >/dev/null 2>&1; then
                        for initramfs in "/boot/${rpreffix}-${kversion}"*; do
                            baseinitrd=$(basename "${initramfs}")
                            iversion=$(echo "${baseinitrd}" | sed -e "s/^${rpreffix}-//" -e "s/.old//")
                            for suffix in "${suffixes[@]}"; do
                                iversion="${iversion/${suffix}/}"
                            done
                            if [[ x$initrd = x"" ]]; then
                                if [[ "${basekernel}" = *?old ]] && [[ "${baseinitrd}" != *?old ]]; then
                                    continue
                                fi
                                found=1
                                kernels+=("${basekernel}|${baseinitrd}")
                                break
                            fi
                        done
                    elif [[ $found = 0 ]]; then
                        kernels+=("${basekernel}|")
                        break
                    fi
                done
            done
        fi
    done
    echo "${kernels[@]}"
}

get_boot_and_root() {
    local devnode mountpoint root boot
    for mount in ${localmounts}; do
        devnode=$(echo "${mount}" | cut -d ':' -f1)
        mountpoint=$(echo "${mount}" | cut -d ':' -f3)
        if [ "${mountpoint}" = "/" ]; then
            root="${devnode}"
        elif [ "${mountpoint}" = "/boot" ] || [ "${mountpoint}" = "/boot/" ]; then
            boot="${devnode}"
        fi
    done
    if [ -z "${boot}" ]; then
        boot="${root}"
    fi
    echo "${boot}|${root}"
}

local_arch=$(get_arch)
if [ -f "modules/bootloader_${local_arch}.sh" ] || [ -f "/usr/share/kicktoo/modules/bootloader_${local_arch}.sh" ]; then
    debug bootloader.sh "loading arch-specific module bootloader_${local_arch}.sh"
    import bootloader_"${local_arch}"
fi
