get_device_size_in_mb() {
    local device=$1

    if [ -h "${device}" ]; then
        device=$(readlink "${device}")
    fi
    device=$(echo "${device}" | sed -e 's:^/dev/::;s:/:\\/:g')
    # just to make sure we don't go past the end of the drive
    echo "$(($(</sys/class/block/"${device}"/size) / 2048 - 2))"
}

human_size_to_mb() {
    local size=$1
    local device_size=$2

    debug human_size_to_mb "size=${size}, device_size=${device_size}"
#    if [ "${size}" = "+" -o "${size}" = "" ]; then
#        debug human_size_to_mb "size is + or blank...using rest of drive"
#        size=""
#        device_size=0
#    else
#        local number_suffix="$(echo ${size} | sed -e 's:\.[0-9]\+::' -e 's:\([0-9]\+\)\([MmGg%]\)[Bb]\?:\1|\2:')"
#        local number="$(echo ${number_suffix} | cut -d '|' -f1)"
#        local suffix="$(echo ${number_suffix} | cut -d '|' -f2)"
#        debug human_size_to_mb "number_suffix='${number_suffix}', number=${number}, suffix=${suffix}"
#        case "${suffix}" in
#            M|m)
#                size="${number}"
#                device_size="$(expr ${device_size} - ${size})"
#                ;;
#            G|g)
#                size="$(expr ${number} \* 1024)"
#                device_size="$(expr ${device_size} - ${size})"
#                ;;
#            %)
#                size="$(expr ${device_size} \* ${number} / 100)"
#                ;;
#            *)
#                size="-1"
#                device_size="-1"
#        esac
#    fi
    debug human_size_to_mb "size=${size}, device_size=${device_size}"
    echo "${size}|${device_size}"
}

format_devnode() {
    local device=$1
    local partition=$2
    local devnode=""

    if echo "${device}" | grep -q '[0-9]$'; then
        devnode="${device}p${partition}"
    else
        devnode="${device}${partition}"
    fi
    echo "${devnode}"
}

fdisk_command() {
    local device=$1
    local cmd=$2

    debug fdisk_command "running fdisk command '${cmd}' on device ${device}"
    spawn "echo -en '${cmd}\nw\n' | fdisk ${device}" && sleep 1 && spawn "hdparm -z ${device}"

    return $?
}

# sparc64 still uses fdisk
sfdisk_command() {
    local device=$1
    local heads sectors cylinders geometry_args
    heads=$(echo "${geometry}" | cut -d: -f1)
    sectors=$(echo "${geometry}" | cut -d: -f2)
    cylinders=$(echo "${geometry}" | cut -d: -f3)

    [ -n "${heads}" ] && geometry_args="-H ${heads}"
    [ -n "${sectors}" ] && geometry_args="${geometry_args} -S ${sectors}"
    [ -n "${cylinders}" ] && geometry_args="${geometry_args} -C ${cylinders}"

    # hdparm -z force really works partprobe not
    debug sfdisk_command "running sfdisk partitions '${partitions}' on device ${device} with geometry ${geometry_args}"
    spawn "echo -e '${partitions}' | sfdisk ${geometry_args} ${device}" || die "could not sfdisk"
    sleep 1
    spawn "hdparm -z ${device}" || die "could not inform kernel of devices changes"
    sleep 1
    # NOTE fix 2048 missing space before first partition, gosh I've chased this one...
    debug sfdisk_command "running fdisk pad 2048 before the first partition"
    spawn "( echo x; echo b; echo 1; echo 2048; echo r; echo w ) | fdisk ${device}" || die "cannot pad 2048 space before first partition (needed for grub:2)"
    return $?
}

local_arch=$(get_arch)
if [ -f "modules/partition_${local_arch}.sh" ] || [ -f "/usr/share/kicktoo/modules/partition_${local_arch}.sh" ]; then
    debug partition.sh "loading arch-specific module partition_${local_arch}.sh"
    import partition_"${local_arch}"
fi
