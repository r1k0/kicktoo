create_disklabel() {
    local device=$1

    debug create_disklabel "creating new msdos disklabel"
    # NOTE fdisk won't convert back from GPT use parted instead
#    fdisk_command ${device} "o" || die "could not create disk label on ${device}"
    spawn "parted ${device} --script -- mklabel msdos" || die "could not create disk label on ${device}"
    return $?
}

add_partition() {
    local device=$1

    # still present for compatibility with partition_sparc64
    # shellcheck disable=SC2034
    local minor=$2

    local size=$3
    local type=$4
    local bootable=$5

    local partition=",${size},${type},${bootable}"
    if [ -z "${partitions}" ]; then
        partitions="${partition}"
    else
        partitions="${partitions}\n${partition}"
    fi
    debug part "partitions are now: ${partitions}"
}
