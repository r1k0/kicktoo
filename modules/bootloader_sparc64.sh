# if [ -z "${bootloader}" ]; then
#     warn "bootloader not set...assuming silo"
#     bootloader="silo"
# fi

configure_bootloader_silo() {
    local boot_root boot boot_minor root kernel_initrd kernel initrd kv
    boot_root="$(get_boot_and_root)"
    boot="$(echo "${boot_root}" | cut -d '|' -f1)"
    boot_minor="$(get_device_and_partition_from_devnode "${boot}" | cut -d '|' -f2)"
    root="$(echo "${boot_root}" | cut -d '|' -f2)"
    kernel_initrd="$(get_kernel_and_initrd)"
    echo -e "partition = ${boot_minor}\ntimeout = 300\nroot = ${root}" >"${chroot_dir}"/boot/silo.conf
    for k in ${kernel_initrd}; do
        kernel="$(echo "${k}" | cut -d '|' -f1)"
        initrd="$(echo "${k}" | cut -d '|' -f2)"
        kv="$(echo "${kernel}" | sed -e 's:^kernel-*-[^-]\+-::' | sed -e 's:[^-]\+-::')"
        echo -e "\nimage = /boot/${kernel}" >>"${chroot_dir}"/boot/silo.conf
        echo "  label = ${kv}" >>"${chroot_dir}"/boot/silo.conf
        if [ -z "${initrd}" ]; then
            echo "  append = \"root=${root}\"" >>"${chroot_dir}"/boot/silo.conf
        else
            echo "  append = \"root=/dev/ram0 init=/linuxrc ramdisk=8192 real_root=${root} ${bootloader_kernel_args}\"" >>"${chroot_dir}"/boot/silo.conf
            echo "  initrd = /boot/${initrd}" >>"${chroot_dir}"/boot/silo.conf
        fi
    done
    if ! spawn_chroot "/sbin/silo -C /boot/silo.conf"; then
        error "could not install silo"
        return 1
    fi
}
