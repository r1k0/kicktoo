get_arch() {
    uname -m | sed -e 's:i[3-6]86:x86:' -e 's:x86_64:amd64:' -e 's:parisc:hppa:'
}

detect_disks() {
    if [ ! -d "/sys" ]; then
        error "Cannot detect disks due to missing /sys"
        exit 1
    fi
    count=0
    for i in /sys/block/[hs]d[a-z]; do
        if [ "$(< ${i}/removable)" = "0" ]; then
            eval "disk${count}=$(basename ${i})"
            count=$(expr ${count} + 1)
        fi
    done
}

get_mac_address() {
    ifconfig | grep HWaddr | head -n 1 | sed -e 's:^.*HWaddr ::' -e 's: .*$::'
}

get_uuid() {
    local device=$1
    blkid -o export ${device} | grep '^UUID' | cut -d '=' -f2
}

detect_baselayout2() {
    spawn_chroot "[ -e /lib/librc.so ]" 
}

# FIXME only works for gentoo/funtoo but not exherbo :(
detect_grub2() {
    # find installed grub version in chroot: 
    #   0 is version 1
    #   1 is version 2
    [ -f ${chroot_dir}/var/db/pkg/sys-boot/grub*/PF ] && vgrub=$(cat ${chroot_dir}/var/db/pkg/sys-boot/grub*/PF | cut -d"-" -f2 | cut -d. -f1)
    if [ "$vgrub" == "1" ] || [ "$vgrub" == "2" ]; then
        bootloader=grub2
    else
        bootloader=grub
    fi
}

check_chroot_fstab() {
    local mountpoint=$1
    if [ "$(grep ${mountpoint} ${chroot_dir}/etc/fstab | awk '{ print $2; }')" == "${mountpoint}" ]; then
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

    local pkg=$1
    if [ -z "$(spawn_chroot \"command -v qlist\")" ]; then
        spawn_chroot "emerge ${emerge_global_opts} portage-utils" 
    fi
    chroot ${chroot_dir} qlist -ICe ${pkg} > /tmp/.pkg.tmp
    isInstalled=$(cat /tmp/.pkg.tmp); rm /tmp/.pkg.tmp
    if [ "$(echo ${isInstalled}|cut -d/ -f2)" == "$(echo ${pkg}|cut -d/ -f2)" ]; then
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
