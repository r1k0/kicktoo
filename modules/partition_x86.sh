create_disklabel() {
    local device=$1
    
    debug create_disklabel "creating new msdos disklabel"
    #NOTE fdisk won't convert back from GPT use parted instead
    #fdisk_command ${device} "o"
    spawn "parted ${device} --script -- mklabel msdos"
    return $?
}

get_num_primary() {
    local device=$1
    
    local primary_count=0
    local device_temp="partitions_$(echo ${device} sed -e 's:^.\+/::')"
    for partition in $(eval echo \${${device_temp}}); do
        debug get_num_primary "partition is ${partition}"
        local minor=$(echo ${partition} | cut -d: -f1)
        if [ "${minor}" -lt "5" ]; then
            primary_count=$(expr ${primary_count} + 1)
            debug get_num_primary "primary_count is ${primary_count}"
        fi
    done
    echo ${primary_count}
}

add_partition() {
    local device=$1
    local minor=$2  # still present for compatibility with partition_sparc64
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
