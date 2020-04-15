#!/usr/bin/env bash

chroot_dir="/mnt/chroot"

chroot_into() {
    local root

    mkdir -p $chroot_dir &>/dev/null
    echo "Checking type of setup: clear, luks or lvm"
    root=$(grep ^mountfs "${profile}" | grep " / " | cut -d" " -f2)
    if is_luks "$root"; then
        echo "Found: $root->$luks_dev luks"
        chroot_luks "$luks_dev"
    elif is_lvm "$root"; then
        echo "Found: $root lvm"
        chroot_lvm "$root"
    else
        echo "Found: $root"
        chroot_clear "$root"
    fi
}

is_luks() {
    # FIXME do more regex checks on profile
    if echo "$1" | grep /dev/mapper 1>/dev/null 2>&1; then
        luks_dev=$(grep luks "${profile}" | grep "$(basename "$1")" | cut -d" " -f2)
        cryptsetup isLuks "$luks_dev"
        return 0
    fi
    return 1
}

is_lvm() {
    # FIXME do more regex checks on profile
    local lvm
    lvm=$(grep ^lvm_volgroup "${profile}")
    [ -z "$lvm" ] && return 1
    return 0
}

chroot_clear() {
    mount "$1" $chroot_dir

    mount -t proc proc ${chroot_dir}/proc &>/dev/null
    mount -o rbind /dev ${chroot_dir}/dev &>/dev/null
    mount -o bind /sys ${chroot_dir}/sys &>/dev/null

    echo "When done:"
    echo " # exit"
    echo " # kicktoo --close <profile>"
    echo "Chrooting..."

    chroot ${chroot_dir} /bin/bash
}

chroot_luks() {
    cryptsetup luksOpen "${1}" root || die "failed auth"
    mount /dev/mapper/root ${chroot_dir}

    mount -t proc proc ${chroot_dir}/proc &>/dev/null
    mount -o rbind /dev ${chroot_dir}/dev &>/dev/null
    mount -o bind /sys ${chroot_dir}/sys &>/dev/null

    echo "When done:"
    echo " # exit"
    echo " # kicktoo --close <profile>"
    echo "Chrooting into LUKS env..."

    chroot ${chroot_dir} /bin/bash
}

chroot_lvm() {
    vgscan
    vgchange -a y

    mount "$1" $chroot_dir

    mount -t proc proc ${chroot_dir}/proc &>/dev/null
    mount -o rbind /dev ${chroot_dir}/dev &>/dev/null
    mount -o bind /sys ${chroot_dir}/sys &>/dev/null

    echo "When done:"
    echo " # exit"
    echo " # kicktoo --close <profile>"
    echo "Run 'mount -a' to mount LVM devices from the chroot"
    echo "Chrooting into LVM env..."

    chroot ${chroot_dir} /bin/bash
}

# FIXME where is chroot_luks_lvm()?

# FIXME where is chroot_mdraid_lvm()?

chroot_close() {
    for i in /dev /sys /proc /boot; do
        if umount -l -f ${chroot_dir}${i} &>/dev/null; then
            echo "${chroot_dir}${i} umounted"
        fi
    done
    if umount -l -f ${chroot_dir} &>/dev/null; then
        echo "${chroot_dir} umounted"
    fi
    if vgchange -a n vg &>/dev/null; then
        echo "lvm volumes closed"
    fi
    if cryptsetup luksClose root &>/dev/null; then
        echo "/dev/mapper/root closed"
    fi
    # clean up current profile's autoresume mount related step points to force them to be remouted next run
    [ -d "${autoresume_profile_dir}" ] && rm "${autoresume_profile_dir}"/{startup_cleanup,mount_*,prepare_chroot,setup_fstab}
    if test -b /dev/mapper/root; then
        echo "Your box is still opened!"
        echo "Rerun 'kicktoo --close <profile>' or reboot"
        exit 1
    fi
}
