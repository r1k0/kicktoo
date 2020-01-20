#!/usr/bin/env bash

get_arch() {
    local arch
    arch=$(uname -m | sed -e 's:i[4-6]86:x86:' -e 's:x86_64:amd64:' -e 's:parisc:hppa:' -e 's:aarch64:arm64:')
    if [[ $arch == arm* ]]; then
        if grep -q vfp /proc/cpuinfo; then
            arch="${arch}_hardfp"
        fi
    fi
    echo "${arch}"
}

get_uuid() {
    local device=$1
    blkid -o export "${device}" | grep '^UUID' | cut -d '=' -f2
}

check_chroot_fstab() {
    local mountpoint=$1
    # INFO make sure /boot is writeable or grub-install in configure_bootloader() will fail with
    #       grub-install failed to get canonical path /boot/grub
    if [ "$mountpoint" == '/boot' ]; then
        mount -o rw,remount "$(grep "${mountpoint}" "${chroot_dir}"/etc/fstab | awk '{ print $1; }')"
    fi
    if [ "$(grep "${mountpoint}" "${chroot_dir}"/etc/fstab | awk '{ print $2; }')" == "${mountpoint}" ]; then
        return 0
    else
        return 1
    fi
}

check_emerge_installed_pkg() {
    # NOTE shame on emerge for not having a native easy-for-scripting option to check if a pkg is installed or not
    # why on earth do we have to install yet another pkg?
    # moreover qlist does not check for reverse deps (pkgs that need install *after* said pkg)
    # so, if CTRL-C is hit when merging post pkgs, this function will NOT see it, pfff
    local pkg is_qlist
    pkg=$1
    is_qlist=$(spawn_chroot "command -v qlist")
    #if [ -z "$(spawn_chroot \"command -v qlist\")" ]; then
    if [ -z "${is_qlist}" ]; then
        spawn_chroot "emerge ${emerge_global_opts} portage-utils"
    fi
    chroot "${chroot_dir}" qlist -ICe "${pkg}" >/tmp/.pkg.tmp
    isInstalled=$(cat /tmp/.pkg.tmp)
    rm /tmp/.pkg.tmp
    if [ "$(echo "${isInstalled}" | cut -d/ -f2)" == "$(echo "${pkg}" | cut -d/ -f2)" ]; then
        isInstalled="${pkg}"
    else
        isInstalled=""
    fi
    if [ -z ${isInstalled} ]; then
        debug check_emerge_installed_pkg "${pkg} not installed, installing now..."
        return 1
    else
        debug check_emerge_installed_pkg "${pkg} already installed, skipping"
        return 0
    fi
}
