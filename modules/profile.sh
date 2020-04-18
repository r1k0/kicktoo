# shellcheck disable=SC2034
# The whole purpose of this file is to translate the profile to
# do_* steps for kicktoo and variables for runsteps

# Set the mode for the profile
mode() {
    mode=$1 # luks - whether this profile shall encrypt partitions
}

# If mode=luks, the key shall be stored on removable USB key
key_on() {
    key_on=$1
}

# Set the disk geometry for the partitioning.
geometry() {
    local heads=$1
    local sectors=$2
    local cylinders=$3

    local geometry_local="${heads}:${sectors}:${cylinders}"
    eval "geometry=\"${geometry_local}\""

    debug geometry "disk geometry is: ${geometry}"
}

# Creates a partition
part() {
    do_part=yes
    local drive=$1    # the drive to add this partition (such as hda, sdb, etc.)
    local minor=$2    # the partition number
    local type=$3     # type used in fdisk (such as 82/S or 83/L) or 85/E/5 for extended
    local size=$4     # the size of the partition in whole numbers, '+' or 'n%' for remaining
    local bootable=$5 # set to "boot" if the partition should be bootable, leave blank for non-bootable

    drive=$(echo "${drive}" | sed -e 's:^/dev/::' -e 's:/:_:g')
    local drive_temp="partitions_${drive}"
    local tmppart="${minor}:${type}:${size}:${bootable}"
    if [ -n "$(eval "echo \${${drive_temp}}")" ]; then
        eval "${drive_temp}=\"$(eval "echo \${${drive_temp}}") ${tmppart}\""
    else
        eval "${drive_temp}=\"${tmppart}\""
    fi
    debug part "${drive_temp} is now: $(eval "echo \${${drive_temp}}")"
}

# Creates a GPT partition
gptpart() {
    do_part=yes
    local drive=$1    # the drive to add this partition (such as hda, sdb, etc.)
    local minor=$2    # the partition number. these should be in order
    local type=$3     # the partition type used in sgdisk (such as 8200 or 8300)
    local size=$4     # the size of the partition in whole numbers, '+' or 'n%' for remaining
    local bootable=$5 # set to "boot" if the partition should be bootable, leave blank for non-bootable

    drive=$(echo "${drive}" | sed -e 's:^/dev/::' -e 's:/:_:g')
    local drive_temp="gptpartitions_${drive}"
    local tmppart="${minor}:${type}:${size}:${bootable}"
    if [ -n "$(eval "echo \${${drive_temp}}")" ]; then
        eval "${drive_temp}=\"$(eval "echo \${${drive_temp}}") ${tmppart}\""
    else
        eval "${drive_temp}=\"${tmppart}\""
    fi
    debug part "${drive_temp} is now: $(eval "echo \${${drive_temp}}")"
}

# Creates a GPT partition, defined using sectors
gptspart() {
    do_part=yes
    local drive=$1 # the drive to add this partition (such as hda, sdb, etc.)
    local minor=$2 # the partition number. these should be in order
    local type=$3  # the partition type used in sgdisk (such as 8200 or 8300)
    local start=$4 # the partition start sector
    local end=$5   # the partition end sector, '+' or 'n%' for remaining

    drive=$(echo "${drive}" | sed -e 's:^/dev/::' -e 's:/:_:g')
    local drive_temp="gptspartitions_${drive}"
    local tmppart="${minor}:${type}:${start}:${end}"
    if [ -n "$(eval "echo \${${drive_temp}}")" ]; then
        eval "${drive_temp}=\"$(eval "echo \${${drive_temp}}") ${tmppart}\""
    else
        eval "${drive_temp}=\"${tmppart}\""
    fi
    debug part "${drive_temp} is now: $(eval "echo \${${drive_temp}}")"
}

# Creates an md raid array
mdraid() {
    do_raid=yes
    local array=$1     # name of the array (such as md0, md1, etc.)
    shift
    local arrayopts=$* # arguments after create: '-l 1 -n 2 /dev/sda2 /dev/sdb2'

    eval "mdraid_${array}=\"${arrayopts}\""
}

# Force the UUID on an md raid array
mduuid() {
    local array=$1 # name of the array (such as md0, md1, etc.)
    local uuid=$2  # uuid to be forced on the array

    eval "mduuid_${array}=${uuid}"
}

# Creates an LVM volume group
lvm_volgroup() {
    do_lvm=yes
    local volgroup=$1 # name of the volume group to create
    shift
    local devices=$*  # list of block devices to include in the volume group

    eval "lvm_volgroup_${volgroup}=\"${devices}\""
}

# Create an LVM logical volume
lvm_logvol() {
    do_lvm=yes
    local volgroup=$1 # name of a volume group created with 'lvm_volgroup'
    local size=$2     # size of logical volume to pass to 'lvcreate'
    local name=$3     # name of logical volume to pass to 'lvcreate'

    local tmplogvol="${volgroup}|${size}|${name}"
    if [ -n "${lvm_logvols}" ]; then
        lvm_logvols="${lvm_logvols} ${tmplogvol}"
    else
        lvm_logvols="${tmplogvol}"
    fi
}

#  Sets and creates /dev/mapper/ encrypted devices
luks() {
    do_luks=yes
    if [ "$1" == "bootpw" ]; then
        boot_password="$2"
        debug luks "Password parsing: $boot_password"
    elif [ "$1" == "key" ]; then
        luks_remdev="$2"
        luks_key="$3"
    else
        local device="$1"
        local luks_mapper="$2" # root, swap
        local cipher_name="$3" # aes or serpent or blowfish
        local cipher_mode="$4" # cbc-essiv or cbc-plain (or else?)
        local hash="$5"        # sha1 or sha256 (or sha512?)

        local tmpluks="${device}:${luks_mapper}:${cipher_name}:${cipher_mode}:${hash}"
        if [ -n "${luks}" ]; then
            luks="${luks} ${tmpluks}"
        else
            luks="${tmpluks}"
        fi
        debug luks "device mapper hash/encryption: ${device} ${luks_mapper} ${cipher_name}/${cipher_mode}/${hash}"
    fi
}

# Formats a partition
format() {
    do_format=yes
    local device="$1" # the device to format (such as /dev/hda2 or /dev/sdb4)
    local fs="$2"     # the filesystem to use (such as ext2, ext3, or swap)
    shift 2
    local options="${*//\ /__}" # the options to use (such as "-O dir_index,huge_file")

    local tmpformat="${device}:${fs}:${options}"
    if [ "${device:0:11}" = '/dev/mapper' ]; then
        if [ -n "${format_luks}" ]; then
            format_luks="${format_luks} ${tmpformat}"
        else
            format_luks="${tmpformat}"
        fi
    else
        if [ -n "${format}" ]; then
            format="${format} ${tmpformat}"
        else
            format="${tmpformat}"
        fi
    fi

}

# Mounts a filesystem
mountfs() {
    do_localmounts=yes
    local device=$1 # the device to mount (such as /dev/hda2 or /dev/sdb4)
    local type=$2   # filesystem of device (use auto if you're not sure)
    local mountpoint=$3
    local mountopts=$4

    [ -z "${mountopts}" ]  && mountopts="defaults"
    [ -z "${mountpoint}" ] && mountpoint="none"
    local tmpmount="${device}:${type}:${mountpoint}:${mountopts}"
    if [ -n "${localmounts}" ]; then
        localmounts="${localmounts} ${tmpmount}"
    else
        localmounts="${tmpmount}"
    fi
}

# Mounts a network filesystem
netmount() {
    do_netmounts=yes
    local export=$1 # path to the network filesystem (such as 1.2.3.4:/some/export)
    local type=$2   # network filesystem type (such as nfs, smbfs, cifs, etc.)
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

# Specify the bootloader to use (defaults to grub)
bootloader() {
    do_bootloader=yes
    local pkg=$1

    bootloader="${pkg}"
}

# Specifies extra commandline arguments to pass to the kernel
bootloader_kernel_args() {
    local kernel_args=${*}

    bootloader_kernel_args="${kernel_args}"
}

# Sets the root password (required if not using rootpw_crypt)
rootpw() {
    do_password=yes
    local pass=$1

    root_password="${pass}"
}

# Sets the root password (required if not using rootpw)
rootpw_crypt() {
    do_password=yes
    local pass=$1

    root_password_hash="${pass}"
}

# FIXME let's have the same for funtoo/exherbo
# Determines the latest stage3 uri
stage_latest() {
    local arch=$1 # A valid stage3 architecture hosted on Gentoo distfiles
    local stage_mainarch

    # setting mainarch for autobuilds release dir
    case "${arch}" in
    i486 | i686)
        stage_mainarch="x86"
        ;;
    arm64 | armv4tl | armv5tel | armv7a | armv7a_hardfp | armv6j | armv6j_hardfp)
        stage_mainarch="arm"
        ;;
    hppa1.1 | hppa2.0)
        stage_mainarch="hppa"
        ;;
    x32)
        stage_mainarch="amd64"
        ;;
    ppc | ppc64 | ppc64le)
        stage_mainarch="ppc"
        ;;
    s390 | s390x)
        stage_mainarch="s390"
        ;;
    sh4 | sh4a)
        stage_mainarch="sh"
        ;;
    sparc | sparc64)
        stage_mainarch="sparc"
        ;;
    *)
        stage_mainarch="${arch}"
        ;;
    esac
    if [ -n "${arch}" ]; then
        local distfiles_base="${distfiles_url}/releases/${stage_mainarch}/autobuilds"
        local latest_stage
        latest_stage=$(curl -s "${distfiles_base}"/latest-stage3-"${arch}".txt | grep -v "^#" | cut -d" " -f1)
        [ -z "${latest_stage}" ] && die "Cannot find the relevant stage tarball, use stage_uri in your profile instead"
        if [ -n "${latest_stage}" ]; then
            stage_uri="${distfiles_base}/${latest_stage}"
            do_stage_uri=yes
            debug stage_latest "latest stage uri is ${stage_uri}"
        fi
    fi
}

# Specifies the URI to the stage tarball (required or use stage_latest)
stage_uri() {
    do_stage_uri=yes
    local uri=$1 # URI to the location of the stage tarball. protocol can be http, https, ftp, or file

    stage_uri="${uri}"
}

# Specifies the filepath to the stage tarball
stage_file() {
    local file=$1

    stage_file="${file}"
}

# Specifies the URI to download a pre-compiled kernel tarball
# tar cfj /usr/src/linux-${version}.tbz2 /boot/*-${version} /etc/kernels/*-${version} /lib/modules/${version}
kernel_uri() {
    do_kernel_uri=yes
    local uri=$1

    kernel_uri="${uri}"
}

# Append a config line to /etc/portage/make.conf
makeconf_line() {
    do_makeconf=yes
    local key val
    key=$(echo "$@" | cut -d= -f1)
    val=$(echo "$@" | cut -d= -f2)

    eval "makeconf_${key}=\"${val}\""
}

# Set locales for /etc/env.d/02locale and /etc/locale.gen
locale_set() {
    do_locale=yes
    locales=$1 # "en_US.UTF-8 nl_NL de"
}

# Specifies the portage tree type, including package snapshots
tree_type() {
    local type=$1 # sync (default), webrsync, or snapshot
    local uri=$2  # location if snapshot and/or packages is type

    if [ "${type}" == "packages" ]; then
        do_packages=yes
        portage_packages_uri="${uri}"
    else
        do_tree=yes
        tree_type="${type}"
        portage_snapshot_uri="${uri}"
    fi
}

# bootloader_install_device - Specifies the device to install the bootloader to
#                             (defaults to MBR of device /boot is on)
#   Parameters:
#     device - device to install bootloader to (such as /dev/hda, /dev/hda3, etc.)
bootloader_install_device() {
    local device=$1

    bootloader_install_device="${device}"
}

# chroot_dir - Specifies the directory to use for the chroot (defaults to
#              /mnt/gentoo)

#   Usage:
#     chroot_dir <dir>

#   Parameters:
#     dir - directory to use for the chroot
chroot_dir() {
    local dir=$1

    chroot_dir="${dir}"
}

# eselect_profile - Select profile using "eselect profile set"
#   Usage:
#     eselect_profile <profile name>
#   Parameters:
#   	eselect_profile default/linux/amd64/13.0
eselect_profile() {
    do_set_profile=yes
    local eprofile=$1

    eselect_profile="${eprofile}"
}

# extra_packages - Specifies extra packages to emerge
#   Parameters:
#     pkg - package (or packages, space-separated) to emerge
extra_packages() {
    do_xpkg=yes
    local pkg=$*

    if [ -n "${extra_packages}" ]; then
        extra_packages="${extra_packages} ${pkg}"
    else
        extra_packages="${pkg}"
    fi
}

# genkernel_kernel_opts - Specifies extra options to pass to genkernel

#   Usage:
#     genkernel_kernel_opts <opts>

#   Parameters:
#     opts - the extra options to pass to 'genkernel kernel'
genkernel_kernel_opts() {
    local opts=$*

    genkernel_kernel_opts="${opts}"
}

# genkernel_initramfs_opts - Specifies extra options to pass to genkernel

#   Usage:
#     genkernel_initramfs_opts <opts>

#   Parameters:
#     opts - the extra options to pass to 'genkernel initramfs'
genkernel_initramfs_opts() {
    local opts=$*

    genkernel_initramfs_opts="${opts}"
}

# kigen_kernel_opts - Specifies extra options to pass to KIGen kernel

#   Usage:
#     kigen_kernel_opts <opts>

#   Parameters:
#     opts - the extra options to pass to KIGen kernel
kigen_kernel_opts() {
    local opts=$*

    kigen_kernel_opts="${opts}"
}

kigen_initramfs_opts() {
    local opts=$*

    kigen_initramfs_opts="${opts}"
}

dracut_initramfs_opts() {
    local opts=$*

    dracut_initramfs_opts="${opts}"
}

# kernel_binary - Specifies the file to a custom kernel binary
#                 If called you should disable all kernel compiling options
#                 such as kernel_config_file, kernel_sources,
#                 genkernel_kernel_opts, genkernel_initramfs_opts

#   Usage:
#     kernel_binary <path>

#   Parameters:
#     path - path to the location of the custom kernel binary
kernel_binary() {
    do_kbin=yes
    local path=$1

    kernel_binary="${path}"
}

# systemmap_binary - Specifies the file to a custom System.map binary

#   Usage:
#     systemmap_binary <path>

#   Parameters:
#     path - path to the location of the custom System.map binary
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

# kernel_builder - Specifies the program to build the kernel and the initramfs
#                  values can either be genkernel OR KIGen (my own genkernel
#                  clone in python)

#   Usage:
#     kernel_builder <app>

#   Parameters:
#     genkernel - use genkernel to build the kernel and its initramfs
#     kigen     - use KIGen to build the kernel and its initramfs (this is
#                 required for LUKS enabled systems and genkernel won't work)
kernel_builder() {
    do_kernel=yes
    local kb=$1

    kernel_builder="${kb}"
}

# kernel_config_uri - Specifies the URI to a custom kernel config

#   Usage:
#     kernel_config_uri <uri>

#   Parameters:
#     uri - URI to the location of the custom kernel config
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

# kernel_sources - Specifies the kernel sources to use (defaults to
#                  gentoo-sources)

#   Usage:
#     kernel_sources <source>

#   Parameters:
#     source - kernel sources to emerge
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

# grub_install - Specifies the device to install grub bootloader to, and options

#   Usage:
#     grub_install <device> <options>

#   Parameters:
#     device  - device to install bootloader to (such as /dev/sda, etc.)
#     options - options to be passed to grub-install
#               note: only --modules options is currently supported

#   Example:
#     grub_install  /dev/sda   --modules="part_gpt mdraid1x lvm xfs"
grub_install() {
    do_bootloader=yes
    local device=$1
    shift
    local opts=$*

    # FIXME only accepts a single option currently (--modules=)
    local key value
    key=$(echo "$opts" | cut -d'=' -f1)
    value=$(echo "$opts" | cut -d'=' -f2)
    grub_install["$(basename "${device}")"]="${key}=\"${value}\""
}

# timezone - Specifies the timezone

#   Usage:
#     timezone <tz>

#   Parameters:
#     tz - timezone to use (relative to /usr/share/zoneinfo/)
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

# rcadd - Adds the specified service to the specified runlevel

#   Usage:
#     rcadd <service> <runlevel>

#   Parameters:
#     service  - name of service to add
#     runlevel - runlevel to add service to
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

# net - Sets up networking

#   Usage:
#     net <device> <ip/dhcp> [gateway]

#   Parameters:
#     device  - network device (such as eth0)
#     ip/dhcp - static IP address or "dhcp"
#     gateway - gateway IP if using a static IP
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

# skip - Skips an install step

#   Usage:
#     skip <install step>

#   Parameters:
#     install step - name of step to skip
skip() {
    local func=$1

    eval "skip_${func}=1"
}

# use_linux32 - Enable the use of linux32 for doing 32ul installs on 64-bit boxes

#   Usage:
#     use_linux32
use_linux32() {
    linux32="linux32"
}
