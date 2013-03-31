source /usr/share/kicktoo/profiles/gentoo/gentoo-sdmmc.profile

stage_latest armv6j_hardfp

post_mount_local_partitions() {
    # getting boot firmware files
    firmware_boot_dir="https://raw.github.com/raspberrypi/firmware/master/boot"

    for f in "bootcode.bin" "fixup.dat" "start.elf" "fixup_cd.dat" "start_cd.elf"; do
        fetch ${firmware_boot_dir}/${f} ${chroot_dir}/boot/${f}
    done

    echo "root=/dev/${DISK}p2 rootdelay=2" > ${chroot_dir}/boot/cmdline.txt
}
