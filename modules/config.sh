geometry() {
    local heads=$1
    local sectors=$2
    local cylinders=$3

    local geometry_local="${heads}:${sectors}:${cylinders}"
    eval "geometry=\"${geometry_local}\""

    debug geometry "disk geometry is: ${geometry}"
}

part() {
    do_part=yes
    local drive=$1
    local minor=$2
    local type=$3
    local size=$4
    local bootable=$5
    
    drive=$(echo ${drive} | sed -e 's:^/dev/::' -e 's:/:_:g')
    local drive_temp="partitions_${drive}"
    local tmppart="${minor}:${type}:${size}:${bootable}"
    if [ -n "$(eval echo \${${drive_temp}})" ]; then
        eval "${drive_temp}=\"$(eval echo \${${drive_temp}}) ${tmppart}\""
    else
        eval "${drive_temp}=\"${tmppart}\""
    fi
    debug part "${drive_temp} is now: $(eval echo \${${drive_temp}})"
}

gptpart() {
    do_part=yes
    local drive=$1
    local minor=$2
    local type=$3
    local size=$4
    local bootable=$5

    drive=$(echo ${drive} | sed -e 's:^/dev/::' -e 's:/:_:g')
    local drive_temp="gptpartitions_${drive}"
    local tmppart="${minor}:${type}:${size}:${bootable}"
    if [ -n "$(eval echo \${${drive_temp}})" ]; then
        eval "${drive_temp}=\"$(eval echo \${${drive_temp}}) ${tmppart}\""
    else
        eval "${drive_temp}=\"${tmppart}\""
    fi
    debug part "${drive_temp} is now: $(eval echo \${${drive_temp}})"
}

mdraid() {
    do_raid=yes
    local array=$1
    shift
    local arrayopts=$@

    eval "mdraid_${array}=\"${arrayopts}\""
}

lvm_volgroup() {
    do_lvm=yes
    local volgroup=$1
    shift
    local devices=$@

    eval "lvm_volgroup_${volgroup}=\"${devices}\""
}

lvm_logvol() {
    do_lvm=yes
    local volgroup=$1
    local size=$2
    local name=$3
    
    local tmplogvol="${volgroup}|${size}|${name}"
    if [ -n "${lvm_logvols}" ]; then
        lvm_logvols="${lvm_logvols} ${tmplogvol}"
    else
        lvm_logvols="${tmplogvol}"
    fi
}

luks() {
    do_luks=yes
    if [ "$1" == "bootpw" ] ; then
        boot_password="$2"
        debug luks "Password parsing: $boot_password"
    else
        local device luks_mapper cipher hash
        device=$1;luks_mapper=$2;cipher=$3;hash=$4

        local tmpluks="${device}:${luks_mapper}:${cipher}:${hash}"
        if [ -n "${luks}" ]; then
            luks="${luks} ${tmpluks}"
        else
            luks="${tmpluks}"
        fi
        debug luks "device mapper hash/encryption: ${device} ${luks_mapper} ${hash}/${cipher}"
    fi
}

format() {
    do_format=yes
    local device=$1
    local fs=$2; shift 2;
    local options=$(echo ${@} | sed s/\ /__/g)
   
    local tmpformat="${device}:${fs}:${options}"
    if [ -n "${format}" ]; then
        format="${format} ${tmpformat}"
    else
        format="${tmpformat}"
    fi
}

mountfs() {
    do_localmounts=yes
    local device=$1
    local type=$2
    local mountpoint=$3
    local mountopts=$4
    
    [ -z "${mountopts}" ] && mountopts="defaults"
    [ -z "${mountpoint}" ] && mountpoint="none"
    local tmpmount="${device}:${type}:${mountpoint}:${mountopts}"
    if [ -n "${localmounts}" ]; then
        localmounts="${localmounts} ${tmpmount}"
    else
        localmounts="${tmpmount}"
    fi
}

netmount() {
    do_netmounts=yes
    local export=$1
    local type=$2
    local mountpoint=$3
    local mountopts=$4
    
    [ -z "${mountopts}" ] && mountopts="defaults"
    local tmpnetmount="${export}|${type}|${mountpoint}|${mountopts}"
    if [ -n "${netmounts}" ]; then
        netmounts="${netmounts} ${tmpnetmount}"
    else
        netmounts="${tmpnetmount}"
    fi
}  

bootloader() {
    do_bootloader=yes
    local pkg=$1

    bootloader="${pkg}"
}

bootloader_kernel_args() {
    local kernel_args=${@}
    
    bootloader_kernel_args="${kernel_args}"
}

rootpw() {
    do_password=yes
    local pass=$1
    
    root_password="${pass}"
}

rootpw_crypt() {
    do_password=yes
    local pass=$1
    
    root_password_hash="${pass}"
}

stage_latest() {
    do_stage_latest=yes
    local arch=$1

    stage_arch="${arch}"

    # setting mainarch for autobuilds release dir
    case "${arch}" in
        i486|i686)
            stage_mainarch="x86" ;;
        armv7a|armv7a_hardfp|armv6j|armv6j_hardfp)
            stage_mainarch="arm" ;;
        *)
            stage_mainarch="${arch}"
    esac
}

stage_uri() {
    do_stage_uri=yes
    local uri=$1
    
    stage_uri="${uri}"
}

stage_file() {
    local file=$1

    stage_file="${file}"
}

makeconf_line() {
    do_makeconf=yes
    local key=$(echo "$@" | cut -d= -f1)
    local val=$(echo "$@" | cut -d= -f2)
    
    eval "makeconf_${key}=\"${val}\""
}

locale_set() {
    do_locale=yes
    locales=$1
}

tree_type() {
    local type=$1
    local uri=$2
    
    if [ "${type}" == "packages" ]; then
        do_packages=yes
        portage_packages_uri="${uri}"
    else
        do_tree=yes
        tree_type="${type}"
        portage_snapshot_uri="${uri}"
    fi
}

bootloader_install_device() {
    local device=$1
    
    bootloader_install_device="${device}"
}

chroot_dir() {
    local dir=$1
    
    chroot_dir="${dir}"
}

extra_packages() {
    do_xpkg=yes
    local pkg=$@
    
    if [ -n "${extra_packages}" ]; then
        extra_packages="${extra_packages} ${pkg}"
    else
        extra_packages="${pkg}"
    fi
}

genkernel_kernel_opts() {
    local opts=$@
    
    genkernel_kernel_opts="${opts}"
}

genkernel_initramfs_opts() {
    local opts=$@
    
    genkernel_initramfs_opts="${opts}"
}

kigen_kernel_opts() {
    local opts=$@

    kigen_kernel_opts="${opts}"
}

kigen_initramfs_opts() {
    local opts=$@

    kigen_initramfs_opts="${opts}"
}

dracut_initramfs_opts() {
    local opts=$@

    dracut_initramfs_opts="${opts}"
}

kernel_binary() {
    do_kbin=yes
    local path=$1

    kernel_binary="${path}"
}

systemmap_binary() {
    do_kbin=yes
    local path=$1

    systemmap_binary="${path}"
}

initramfs_binary() {
    do_irfsbin=yes
    local path=$1

    initramfs_binary="${path}"
}

kernel_builder() {
    do_kernel=yes
    local kb=$1

    kernel_builder="${kb}"
}

kernel_config_uri() {
    do_kernel=yes
    local uri=$1
    
    kernel_config_uri="${uri}"
}

kernel_config_file() {
    do_kernel=yes
    local file=$1
    
    kernel_config_file="${file}"
}

kernel_sources() {
    do_kernel=yes
    local pkg=$1

    kernel_sources="${pkg}"
}

initramfs_builder() {
    do_irfs=yes
    local irfsb=$1
    
    # defaults to genkernel
    [ -z "${irfsb}" ] && irfsb="genkernel"

    initramfs_builder="${irfsb}"
}

timezone() {
    do_tz=yes
    local tz=$1
    
    timezone="${tz}"
}

keymap() {
    do_keymap=yes
    local kbd=$1

    keymap="${kbd}"
}

hostname() {
    do_host=yes
    local host=$1

    hostname="${host}"
}

domain() {
    do_domain="yes"
    local domain=$1
    
    domain_name="${domain}"
}

rcadd() {
    do_services=yes
    local service=$1
    local runlevel=$2
    
    local tmprcadd="${service}|${runlevel}"
    if [ -n "${services_add}" ]; then
        services_add="${services_add} ${tmprcadd}"
    else
        services_add="${tmprcadd}"
    fi
}

rcdel() {
    local service=$1
    local runlevel=$2
    
    local tmprcdel="${service}|${runlevel}"
    if [ -n "${services_del}" ]; then
        services_del="${services_del} ${tmprcdel}"
    else
        services_del="${tmprcdel}"
    fi
}

net() {
    do_postnet=yes
    local device=$1
    local ipdhcp=$2
    local gateway=$3
    
    local tmpnet="${device}|${ipdhcp}|${gateway}"
    if [ -n "${net_devices}" ]; then
        net_devices="${net_devices} ${tmpnet}"
    else
        net_devices="${tmpnet}"
    fi
}

logfile() {
    local file=$1
    
    logfile=${file}
}

skip() {
    local func=$1
    
    eval "skip_${func}=1"
}

server() {
    server=$1
    server_init
}

use_linux32() {
    linux32="linux32"
}
