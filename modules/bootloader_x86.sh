#!/usr/bin/env bash

configure_bootloader_grub() {
    debug configure_bootloader_grub "configuring and deploying grub"

    check_chroot_fstab /boot && spawn_chroot "[ -z \"\$(mount | grep /boot)\" ] && mount /boot"

    local key value
    for device in "${!grub_install[@]}"; do
        # FIXME only accepts a single option currently (--modules=)
        key=$(echo "${grub_install["${device}"]}" | cut -d'=' -f1)
        value=$(echo "${grub_install["${device}"]}" | cut -d'=' -f2)

        if [ -n "${key}" ] && [ -n "${value}" ]; then
            debug configure_bootloader_grub "deploying grub-install $key=$value /dev/${device}"
            spawn_chroot "grub-install ${key}=${value} /dev/${device}" || die "Could not deploy grub-install $key=$value /dev/${device}"
        else
            debug configure_bootloader_grub "deploying grub-install /dev/${device}"
            spawn_chroot "grub-install /dev/${device}" || die "Could not deploy grub-install /dev/${device}"
        fi
        #spawn_chroot "grub-install --modules=\"part_gpt mdraid1x lvm xfs\" /dev/sda" || die "Could not deploy with grub-install on /dev/sda"
        #spawn_chroot "grub-install --modules=\"part_gpt mdraid1x lvm xfs\" /dev/sdb" || die "Could not deploy with grub-install on /dev/sdb"
    done

    local args
    if [ -n "${bootloader_kernel_args}" ]; then
        args=$(echo "${bootloader_kernel_args}" |
            sed -e "s:{{root_keydev_uuid}}:$(get_uuid "${luks_remdev}"):" |
            sed -e "s:{{root_key}}:${luks_key}:")
        debug configure_bootloader_grub "GRUB_CMDLINE_LINUX=${args} to /etc/default/grub"
        spawn "cp -f ${chroot_dir}/etc/default/grub ${chroot_dir}/etc/default/grub.example" || die "Could not copy ${chroot_dir}/etc/default/grub to ${chroot_dir}/etc/default/grub.example"
        spawn "cat ${chroot_dir}/etc/default/grub.example | grep -v ^#.* > ${chroot_dir}/etc/default/grub" || die "Could not filter comments out from ${chroot_dir}/etc/default/grub"
        spawn "echo -e '\n\nGRUB_CMDLINE_LINUX=\"\$GRUB_CMDLINE_LINUX ${args}\"' >> ${chroot_dir}/etc/default/grub" || die "Could not add dolvm option to ${chroot_dir}/etc/default/grub"
    fi
    debug configure_grub "generating /boot/grub/grub.cfg"
    spawn_chroot "grub-mkconfig -o /boot/grub/grub.cfg" || die "Could not generate /boot/grub/grub.cfg"
}

configure_bootloader_lilo() {
    debug configure_bootloader_lilo "configuring /etc/lilo.conf"
    local boot_root boot boot_device root kernel_initrd kernel initrd
    boot_root="$(get_boot_and_root)"
    boot="$(echo "${boot_root}" | cut -d '|' -f1)"
    boot_device="$(get_device_and_partition_from_devnode "${boot}" | cut -d '|' -f1)"
    root="$(echo "${boot_root}" | cut -d '|' -f2)"
    kernel_initrd="$(get_kernel_and_initrd)"
    echo -e "boot=${boot_device}" >"${chroot_dir}"/etc/lilo.conf
    echo -e "prompt" >>"${chroot_dir}"/etc/lilo.conf
    echo -e "timeout=20" >>"${chroot_dir}"/etc/lilo.conf
    for k in ${kernel_initrd}; do
        kernel="$(echo "${k}" | cut -d '|' -f1)"
        initrd="$(echo "${k}" | cut -d '|' -f2)"
        echo -e "image=/boot/${kernel}"
        echo -e "  label=${hostname}"
        echo -e "  read-only" >>"${chroot_dir}"/etc/lilo.conf
        if [ -z "${initrd}" ]; then
            # this is for non initramfs enabled
            echo -e "  root=${root}" >>"${chroot_dir}"/etc/lilo.conf
            [ -n "${bootloader_kernel_args}" ] && echo -e "  append=\"${bootloader_kernel_args}\"" >>"${chroot_dir}"/etc/lilo.conf
        else
            echo -e "  append=\"root=/dev/ram0 init=/linuxrc ramdisk=8192 real_root=${root} ${bootloader_kernel_args}\"" >>"${chroot_dir}"/etc/lilo.conf
            echo -e "  initrd=/boot/${initrd}\n" >>"${chroot_dir}"/etc/lilo.conf
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
