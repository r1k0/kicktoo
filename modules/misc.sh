get_arch() {
    local arch=$(uname -m | sed -e 's:i[4-6]86:x86:' -e 's:x86_64:amd64:' -e 's:parisc:hppa:' -e 's:aarch64:arm64:')
    if [[ $arch == arm* ]]; then
        if grep -q vfp /proc/cpuinfo; then
            arch="${arch}_hardfp"
        fi
    fi
    echo "${arch}"
}

get_mac_address() {
    ifconfig | grep HWaddr | head -n 1 | sed -e 's:^.*HWaddr ::' -e 's: .*$::'
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
    local pkg=$1
    local is_qlist=$(spawn_chroot "command -v qlist")
    #if [ -z "$(spawn_chroot \"command -v qlist\")" ]; then
    if [ -z "${is_qlist}" ]; then
        spawn_chroot "emerge ${emerge_global_opts} portage-utils"
    fi
    chroot "${chroot_dir}" qlist -ICe "${pkg}" >/tmp/.pkg.tmp
    isInstalled=$(cat /tmp/.pkg.tmp)
    rm -f /tmp/.pkg.tmp
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

secs_to_minutes_to_hours() {
	  local h m s
    if [[ -z "${1}" || "${1}" -lt 60 ]] ;then
        s="${1}"
        echo "${s}s"
    elif [[ -z "${1}" || "${1}" -lt 3600 && "${1}" -gt 60 ]]; then
        time_mins=$(echo "scale=2; ${1}/60" | bc)
        m=$(echo ${time_mins}    | cut -d'.' -f1)
        s="0.$(echo ${time_mins} | cut -d'.' -f2)"
        s=$(echo ${s}*60 | bc | awk '{print int($1+0.5)}')
        echo "${m}m ${s}s"
    elif [[ -z "${1}" || "${1}" -gt 3600 ]]; then
        time_mins=$(echo "scale=2; ${1}/60" | bc)
        time_hours=$(echo "scale=2; ${1}/3600" | bc)
        h=$(echo ${time_hours}    | cut -d'.' -f1)
        m="0.$(echo ${time_hours} | cut -d'.' -f2)"
        m=$(echo ${m}*60 | bc | awk '{print int($1+0.5)}')  # ???
        s="0.$(echo ${time_mins} | cut -d'.' -f2)"
        s=$(echo ${s}*60 | bc | awk '{print int($1+0.5)}')
        echo "${h}h ${m}m ${s}s"
    fi
}
