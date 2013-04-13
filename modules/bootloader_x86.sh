configure_bootloader_grub() {
    debug configure_bootloader_grub "configuring /boot/grub/grub.conf"

    check_chroot_fstab /boot && spawn_chroot "[ -z \"\$(mount | grep /boot)\" ] && mount /boot"            
    echo -e "default 0\ntimeout 5\n" > ${chroot_dir}/boot/grub/grub.conf
    local boot_root="$(get_boot_and_root)"
    local boot="$(echo ${boot_root} | cut -d '|' -f1)"
    local boot_device="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f1)"
    local boot_minor="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f2)"
    local root="$(echo ${boot_root} | cut -d '|' -f2)"
    local kernel_initrd="$(get_kernel_and_initrd)"

    for k in ${kernel_initrd}; do
        local kernel="$(echo ${k}  | cut -d '|' -f1)"
        local initrd="$(echo ${k}  | cut -d '|' -f2)"
        local kv="$(echo ${kernel} | sed -e 's:^kernel-*-[^-]\+-::' | sed -e 's:[^-]\+-::')"
        echo "title=${distro} Linux ${kv}" >> ${chroot_dir}/boot/grub/grub.conf
        if [ "${boot_device}" == "/dev/md" ]; then
            local md_devices="$(grep ${boot#/dev/} /proc/mdstat |grep -o [hs]d[a-z][0-9] |sort)" #|sed -e '{:q;N;s/\n/|/g;t q}')"
            boot_device="/dev/$(echo ${md_devices} |cut -d ' ' -f1 |grep -o '[a-z]*')"
        fi
        local grub_device="$(map_device_to_grub_device ${boot_device})"
        if [ -z "${grub_device}" ]; then
            error "Could not map boot device ${boot_device} to grub device"
            return 1
        fi
        echo -en "root (${grub_device},$(expr ${boot_minor} - 1))\nkernel /boot/${kernel} " >> ${chroot_dir}/boot/grub/grub.conf
        if [ -z "${initrd}" ]; then
            echo "root=${root}" >> ${chroot_dir}/boot/grub/grub.conf
        else
            echo "root=/dev/ram0 init=/linuxrc ramdisk=8192 real_root=${root} ${bootloader_kernel_args}" >> ${chroot_dir}/boot/grub/grub.conf
            echo -e "initrd /boot/${initrd}\n" >> ${chroot_dir}/boot/grub/grub.conf
        fi
    done
    if ! spawn_chroot "grep -v rootfs /proc/mounts > /etc/mtab"; then
        error "Could not copy /proc/mounts to /etc/mtab"
        return 1
    fi

    if [[ "${boot}" =~ ^/dev/md ]]; then
        for md_dev_node in ${md_devices}; do
            # NOTE redirect output to /dev/null otherwise the fb wont redraw its entire resolution after pipping to grub
            spawn_chroot "echo -en \"device (hd0) /dev/${md_dev_node%[0-9]*}\nroot (hd0,0)\nsetup (hd0)\nquit\n\" | grub >/dev/null 2>&1"
        done
    else
        [ -z "${bootloader_install_device}" ] && bootloader_install_device="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f1)"
        if ! spawn_chroot "grub-install ${bootloader_install_device}"; then
            error "Could not install grub to ${bootloader_install_device}"
            return 1
        fi
    fi
}

# good stuff but it breaks for a few cases on default profiles 
# keeping here for later
#configure_bootloader_grub2() {
#    debug configure_bootloader_grub2 "configuring and deploying grub2"
#
#    for device in "${!grub2_install[@]}"; do
##       FIXME - only accepts a single option currently (--modules=)        
#        local key=$(echo ${grub2_install["${device}"]} | cut -d'=' -f1)
#        local value=$(echo ${grub2_install["${device}"]} | cut -d'=' -f2)
#    
#        debug configure_bootloader_grub2 "deploying grub2-install $key=$value /dev/${device}"
#        spawn_chroot "grub2-install $key=$value /dev/${device}" || die "Could not deploy grub2-install $key=$value /dev/${device}"
#        #spawn "grub2-install $key=$value /dev/${device}" || die "Could not deploy grub2-install $key=$value /dev/${device}"
#                
#        #spawn_chroot "grub2-install --modules=\"part_gpt mdraid1x lvm xfs\" /dev/sda" || die "Could not deploy with grub2-install on /dev/sda"
#        #spawn_chroot "grub2-install --modules=\"part_gpt mdraid1x lvm xfs\" /dev/sdb" || die "Could not deploy with grub2-install on /dev/sdb"
#    done
#    
#    if [ -n "${bootloader_kernel_args}" ]; then
#        local args=$(echo ${bootloader_kernel_args} | \
#        sed -e 's:{{root_keydev_uuid}}:$(get_uuid ${luks_remdev}):' | \
#        sed -e 's:{{root_key}}:${luks_key}:')
#        debug configure_bootloader_grub2 "GRUB_CMDLINE_LINUX=$(echo ${args}) to /etc/default/grub"
#        spawn "sed -i 's:GRUB_CMDLINE_LINUX=\"\":GRUB_CMDLINE_LINUX=\"'\"${args}\"'\":' ${chroot_dir}/etc/default/grub" || \
#        die "Could not adjust GRUB_CMDLINE_LINUX with bootloader args $(echo ${args})"
#    fi
#    debug configure_grub2 "generating /boot/grub2/grub.cfg"
#    spawn_chroot "grub2-mkconfig -o /boot/grub2/grub.cfg" || die "Could not generate /boot/grub2/grub.cfg"
#}

configure_bootloader_grub2() {
    debug configure_bootloader_grub2 "configuring /boot/grub/grub.cfg"
    echo -e "set default=0\nset timeout=5\n" > ${chroot_dir}/boot/grub/grub.cfg
    local boot_root="$(get_boot_and_root)"
    local boot="$(echo ${boot_root} | cut -d '|' -f1)"
    local boot_device="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f1)"
    local boot_minor="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f2)"
    local root="$(echo ${boot_root} | cut -d '|' -f2)"
    local kernel_initrd="$(get_kernel_and_initrd)"

    for k in ${kernel_initrd}; do
        local kernel="$(echo ${k}  | cut -d '|' -f1)"
        local initrd="$(echo ${k}  | cut -d '|' -f2)"
        local kv="$(echo ${kernel} | sed -e 's:^kernel-*-[^-]\+-::' | sed -e 's:[^-]\+-::')"
        echo "menuentry \"${distro} Linux ${kv}\" {" >> ${chroot_dir}/boot/grub/grub.cfg
        local grub_device="$(map_device_to_grub2_device ${boot_device})"
        if [ -z "${grub_device}" ]; then
            error "Could not map boot device ${boot_device} to grub device"
            return 1
        fi
        echo -en "set root=(${grub_device},$(expr ${boot_minor}))\nlinux /${kernel} " >> ${chroot_dir}/boot/grub/grub.cfg
        if [ -z "${initrd}" ]; then
            echo "root=${root}" >> ${chroot_dir}/boot/grub/grub.cfg
        else
            echo "root=/dev/ram0 init=/linuxrc ramdisk=8192 real_root=${root} ${bootloader_kernel_args}" >> ${chroot_dir}/boot/grub/grub.cfg
            echo -e "initrd /${initrd}\n" >> ${chroot_dir}/boot/grub/grub.cfg
        fi
        echo -e "}\n" >> ${chroot_dir}/boot/grub/grub.cfg
    done
    if ! spawn_chroot "grep -v rootfs /proc/mounts > /etc/mtab"; then
        error "Could not copy /proc/mounts to /etc/mtab"
        return 1
    fi
    [ -z "${bootloader_install_device}" ] && bootloader_install_device="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f1)"
    if ! spawn_chroot "grub-install ${bootloader_install_device}"; then
        error "Could not install grub to ${bootloader_install_device}"
        return 1
    fi
}

configure_bootloader_lilo() {
    debug configure_bootloader_lilo "configuring /etc/lilo.conf"
    local boot_root="$(get_boot_and_root)"
    local boot="$(echo ${boot_root} | cut -d '|' -f1)"
    local boot_device="$(get_device_and_partition_from_devnode ${boot} | cut -d '|' -f1)"
    local boot_minor="$(get_device_and_partition_from_devnode ${boot}  | cut -d '|' -f2)"
    local root="$(echo ${boot_root} | cut -d '|' -f2)"
    local kernel_initrd="$(get_kernel_and_initrd)"
    echo -e "boot=${boot_device}" > ${chroot_dir}/etc/lilo.conf
    echo -e "prompt" >> ${chroot_dir}/etc/lilo.conf
    echo -e "timeout=20" >> ${chroot_dir}/etc/lilo.conf
    for k in ${kernel_initrd}; do
        local kernel="$(echo ${k}  | cut -d '|' -f1)"
        local initrd="$(echo ${k}  | cut -d '|' -f2)"
        local kv="$(echo ${kernel} | sed -e 's:^kernel-*-[^-]\+-::' | sed -e 's:[^-]\+-::')"
        echo -e "image=/boot/${kernel}"              >> ${chroot_dir}/etc/lilo.conf
        echo -e "  label=${hostname}"                >> ${chroot_dir}/etc/lilo.conf
        echo -e "  read-only"                        >> ${chroot_dir}/etc/lilo.conf
        if [ -z "${initrd}" ]; then
            # this is for non initramfs enabled
            echo -e "  root=${root}"                 >> ${chroot_dir}/etc/lilo.conf
            [ -n "${bootloader_kernel_args}" ] && echo -e "  append=\"${bootloader_kernel_args}\"" >> ${chroot_dir}/etc/lilo.conf
        else 
            echo -e "  append=\"root=/dev/ram0 init=/linuxrc ramdisk=8192 real_root=${root} ${bootloader_kernel_args}\"" >> ${chroot_dir}/etc/lilo.conf
            echo -e "  initrd=/boot/${initrd}\n"     >> ${chroot_dir}/etc/lilo.conf
        fi
    done
    if ! spawn_chroot "grep -v rootfs /proc/mounts > /etc/mtab"; then
        error "Could not copy /proc/mounts to /etc/mtab"
        return 1
    fi
    if ! spawn_chroot "lilo"; then
        error "Could not run lilo"
        return 1
    fi
}
