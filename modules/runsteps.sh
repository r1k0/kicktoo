run_pre_install_script() {
    if [ -n "${pre_install_script_uri}" ]; then
        fetch "${pre_install_script_uri}" "${chroot_dir}/var/tmp/pre_install_script" || die "Could not fetch pre-install script"
        chmod +x "${chroot_dir}/var/tmp/pre_install_script"
        spawn_chroot "/var/tmp/pre_install_script" || die "error running pre-install script"
        spawn "rm ${chroot_dir}/var/tmp/pre_install_script"
    elif isafunc pre_install; then
        pre_install || die "error running pre_install()"
    else
        debug run_pre_install_script "no pre-install script set"
    fi
}

partition() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    for device in $(set | grep '^partitions_' | cut -d= -f1 | sed -e 's:^partitions_::'); do
        debug partition "device is ${device}"
        [ -e "/dev/${device}" ] || die "/dev/${device} does not exist"
        local device_temp="partitions_${device}"
        local device_size minor ptype size
        device="/dev/${device/_/\/}"
        device_size="$(get_device_size_in_mb "${device}")"
        create_disklabel "${device}" || die "Could not create disklabel for device ${device}"
        for partition in $(eval "echo \${${device_temp}}"); do
            debug partition "partition is ${partition}"
            minor=$(echo "${partition}" | cut -d: -f1)
            ptype=$(echo "${partition}" | cut -d: -f2)
            size=$(echo "${partition}" | cut -d: -f3)
            bootable=$(echo "${partition}" | cut -d: -f4)
            devnode=$(format_devnode "${device}" "${minor}")
            debug partition "devnode is ${devnode}"
            # [E|S|L|X], where L (LINUX_NATIVE (83)) is the default, S is LINUX_SWAP (82), E is EXTENDED_PARTITION (5), and X is LINUX_EXTENDED (85).
            # FIXME so.. 5 and 85 is not the same?
            if [ "${ptype}" == "E" ] || [ "${ptype}" == "5" ] || [ "${ptype}" == "85" ]; then
                newsize="${device_size}"
                inputsize=""
            else
                size_devicesize="$(human_size_to_mb "${size}" "${device_size}")"
                newsize="$(echo "${size_devicesize}" | cut -d '|' -f1)"
                [ "${newsize}" == "-1" ] && die "Could not translate size '${size}' to a usable value"
                device_size="$(echo "${size_devicesize}" | cut -d '|' -f2)"
                inputsize="${newsize}"
            fi
            [ -n "${bootable}" ] && bootable="*"

            add_partition "${device}" "${minor}" "${inputsize}" "${ptype}" "${bootable}" || die "Could not add partition ${minor} to device ${device}"
        done
        if [ "$(get_arch)" != "sparc64" ]; then
            # FIXME isnt it here where I should pad 2M at the very start of the device?
            # writing added partitions to device
            sfdisk_command "${device}" || die "Could not write partitions ${partitions} to device ${device}"
            # clear partitions for next device
            partitions=""
        fi
    done

    # GPT partitioning
    # http://www.funtoo.org/wiki/Funtoo_Linux_Installation#Prepare_Hard_Disk
    for device in $(set | grep '^gptpartitions_' | cut -d= -f1 | sed -e 's:^gptpartitions_::'); do
        debug partition "device is ${device}"
        [ -e "/dev/${device}" ] || die "/dev/${device} does not exist"
        local device_temp="gptpartitions_${device}"
        local device_size minor ptype size bootable devnode
        device="/dev/${device/_/\/}"
        device_size="$(get_device_size_in_mb "${device}")"
        # clean part table and convert to GPT
        spawn "sgdisk -og ${device}" || die "Cannot sgdisk -og ${device}"
        for partition in $(eval "echo \${${device_temp}}"); do
            debug partition "partition is ${partition}"
            minor=$(echo "${partition}"    | cut -d: -f1)
            ptype=$(echo "${partition}"    | cut -d: -f2)
            size=$(echo "${partition}"     | cut -d: -f3)
            bootable=$(echo "${partition}" | cut -d: -f4)
            devnode=$(format_devnode "${device}" "${minor}")
            debug partition "devnode is ${devnode}"
            # FIXME check if the boot option is even possible for sgdisk
            [ -n "${bootable}" ] && bootable="*"

            [ "${size}" == "+" ] && size= # a single + is enough
            spawn "sgdisk -g -n ${minor}::+${size} -t ${minor}:${ptype} ${device}" || die "Could not add GPT partition ${minor} to ${device}"
            #spawn "hdparm -z ${device}" || die "Could not update partition table to kernel"
        done
    done

    # GPT partitioning using sectors
    # http://www.rodsbooks.com/gdisk/sgdisk-walkthrough.html
    for device in $(set | grep '^gptspartitions_' | cut -d= -f1 | sed -e 's:^gptspartitions_::'); do
        debug partition "device is ${device}"
        local device_temp="gptspartitions_${device}"
        local device_size minor ptype start end devnode
        device="/dev/${device/_/\/}"
        device_size="$(get_device_size_in_mb "${device}")"
        # clean part table and convert to GPT
        spawn "sgdisk -og ${device}" || die "Cannot sgdisk -og ${device}"
        for partition in $(eval "echo \${${device_temp}}"); do
            debug partition "partition is ${partition}"
            minor=$(echo "${partition}" | cut -d: -f1)
            ptype=$(echo "${partition}" | cut -d: -f2)
            start=$(echo "${partition}" | cut -d: -f3)
            end=$(echo "${partition}"   | cut -d: -f4)
            devnode=$(format_devnode "${device}" "${minor}")
            debug partition "devnode is ${devnode}"

            spawn "sgdisk -g -n ${minor}:${start}:${end} -t ${minor}:${ptype} ${device}" || die "Could not add GPT partition ${minor} to ${device}"
            #spawn "hdparm -z ${device}" || die "Could not update partition table to kernel"
        done
        sleep 2 # this helps getting newly created partitions recognized by the system
    done

}

setup_mdraid() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    if ! [ -f "${autoresume_profile_dir}/setup_mdraid" ]; then
        for array in $(set | grep '^mdraid_' | cut -d= -f1 | sed -e 's:^mdraid_::' | sort); do
            debug setup_mdraid "creating RAID array ${array}"
            local array_temp="mdraid_${array}"
            local arrayopts arraynum uuid devices
            arrayopts=$(eval "echo \${${array_temp}}")
            arraynum="${array/#md/}"
            if [ ! -e "/dev/md${arraynum}" ]; then
                spawn "mknod /dev/md${arraynum} b 9 ${arraynum}" || die "Could not create device node for mdraid array ${array}"
            fi
            spawn "mdadm --create /dev/${array} --run ${arrayopts}" || die "Could not create mdraid array ${array}"
            if [ -n "$(eval "echo \${mduuid_${array}}")" ]; then
                uuid=$(eval "echo \${mduuid_${array}}")
                spawn "mdadm --stop /dev/${array}" || die "Could not stop mdraid array ${array}"
                devices="/dev$(echo "${arrayopts}" | sed -e 's/\/dev/$/' | cut -d'$' -f2-)"
                spawn "mdadm --assemble /dev/${array} --run --update=uuid --uuid=${uuid} ${devices}" || die "Could not assemble and update mdraid array ${array} with uuid=${uuid}"
            fi
        done

    elif [ "${autoresume}" == "yes" ] && [ -f "${autoresume_profile_dir}/setup_mdraid" ]; then
        # we add raid device, don't create them
        for array in $(set | grep '^mdraid_' | cut -d= -f1 | sed -e 's:^mdraid_::' | sort); do
            debug setup_mdraid "adding RAID array ${array}"
            local array_temp="mdraid_${array}"
            local arrayopts arraynum devices
            arrayopts=$(eval "echo \${${array_temp}}")
            arraynum="${array/#md/}"
            # FIXME find a cleaner regexp to extract the first occurene of /dev/sd.? from ${arrayopts}
            #spawn "mdadm /dev/${array} -A /$(echo ${arrayopts}|sed -e 's/ //g'|cut -d'/' -f2)/$(echo ${arrayopts}|sed -e 's/ //g'|cut -d'/' -f3) --run" || die "Could not activate mdraid array ${array}"
            devices="/dev$(echo "${arrayopts}" | sed -e 's/\/dev/$/' | cut -d'$' -f2-)"
            spawn "mdadm --assemble /dev/${array} --run ${devices}" || die "Could not activate mdraid array ${array}"
        done
    fi
}

setup_lvm() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    if ! [ -f "$autoresume_profile_dir/setup_lvm" ]; then
        local volgroup_devices size name
        for volgroup in $(set | grep '^lvm_volgroup_' | cut -d= -f1 | sed -e 's:^lvm_volgroup_::' | sort); do
            debug setup_lvm "creating LVM group ${volgroup}"
            local volgroup_temp="lvm_volgroup_${volgroup}"
            volgroup_devices="$(eval "echo \${${volgroup_temp}}")"
            for device in ${volgroup_devices}; do
                sleep 1
                spawn "pvcreate -ffy ${device}" || die "Could not run 'pvcreate' on ${device}"
            done
            spawn "vgcreate ${volgroup} ${volgroup_devices}" || die "Could not create volume group '${volgroup}' from devices: ${volgroup_devices}"
        done
        for logvol in ${lvm_logvols}; do
            debug setup_lvm "creating LVM volume ${logvol}"
            sleep 1
            volgroup="$(echo "${logvol}" | cut -d '|' -f1)"
            size="$(echo "${logvol}"     | cut -d '|' -f2)"
            name="$(echo "${logvol}"     | cut -d '|' -f3)"
            spawn "lvcreate -L${size} -n${name} ${volgroup}" || die "Could not create logical volume '${name}' with size ${size} in volume group '${volgroup}'"
        done
    elif [ "${autoresume}" == "yes" ] && [ -f "$autoresume_profile_dir/setup_lvm" ]; then
        # scan for lvm devices
        debug setup_lvm "scanning for LVM devices"
        spawn "vgscan" || die "Could not vgscan previously created lvm volumes"
        spawn "vgchange -a y" || die "Could not vgchange -a y previously created lvm volumes"
    fi
}

setup_luks() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    local devicetmp luks_mapper cipher_name cipher_mode lhash lukscmd=""
    if ! [ -f "${autoresume_profile_dir}/setup_luks" ]; then
        if [ -n "${luks_key}" ]; then
            debug setup_luks "generating encryption key ${luks_key} on ${luks_remdev}"
            mkdir -p /mnt/"$(basename "${luks_remdev}")"
            spawn "mount ${luks_remdev} /mnt/$(basename "${luks_remdev}")" || die "Could not mount ${luks_remdev} on /mnt/$(basename "${luks_remdev}")"
            spawn "cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c${1:-40} > /mnt/$(basename "${luks_remdev}")${luks_key}"
        fi
        for device in ${luks}; do
            debug setup_luks "LUKSifying ${device}"

            devicetmp=$(echo "${device}"   | cut -d: -f1)
            luks_mapper=$(echo "${device}" | cut -d: -f2)
            cipher_name=$(echo "${device}" | cut -d: -f3)
            cipher_mode=$(echo "${device}" | cut -d: -f4)
            lhash=$(echo "${device}"       | cut -d: -f5)
            case ${luks_mapper} in
            swap)
                lukscmd="cryptsetup -q -c ${cipher_name} -h ${lhash} -d /dev/urandom create ${luks_mapper} ${devicetmp}"
                ;;
            *)
                if [ -n "${luks_key}" ]; then
                    lukscmd="cryptsetup -c ${cipher_name}-${cipher_mode}:${lhash} luksFormat ${devicetmp} /mnt/$(basename "${luks_remdev}")${luks_key} && \
                        cryptsetup --key-file /mnt/$(basename "${luks_remdev}")${luks_key} luksOpen ${devicetmp} ${luks_mapper}"
                else
                    lukscmd="echo ${boot_password} | cryptsetup -c ${cipher_name}-${cipher_mode}:${lhash} luksFormat ${devicetmp} && echo ${boot_password} | cryptsetup luksOpen ${devicetmp} ${luks_mapper}"
                fi
                ;;
            esac
            if [ -n "${lukscmd}" ]; then
                spawn "${lukscmd}" || die "Could not luks: ${lukscmd}"
            fi
        done
    elif [ "${autoresume}" == "yes" ] && [ -f "${autoresume_profile_dir}/setup_luks" ]; then
        for device in ${luks}; do
            debug setup_luks "LUKSifying ${device}"

            devicetmp=$(echo "${device}"   | cut -d: -f1)
            luks_mapper=$(echo "${device}" | cut -d: -f2)
            cipher_name=$(echo "${device}" | cut -d: -f3)
            cipher_mode=$(echo "${device}" | cut -d: -f4)
            lhash=$(echo "${device}"       | cut -d: -f5)
            case ${luks_mapper} in
            swap)
                lukscmd="cryptsetup -q -c ${cipher_name} -h ${lhash} -d /dev/urandom create ${luks_mapper} ${devicetmp}"
                ;;
            *)
                if [ -n "${luks_key}" ]; then
                    lukscmd="cryptsetup --key-file /mnt/$(basename "${luks_remdev}")${luks_key} luksOpen ${devicetmp} ${luks_mapper}"
                else
                    lukscmd="echo ${boot_password} | cryptsetup luksOpen ${devicetmp} ${luks_mapper}"
                fi
                ;;
            esac
            if [ -n "${lukscmd}" ]; then
                spawn "${lukscmd}" || die "Could not luks: ${lukscmd}"
            fi
        done
    fi
    unset boot_password # we don't need it anymore
    if [ -n "${luks_key}" ]; then
        if grep -q ^"${luks_remdev}" /proc/mounts; then
            spawn "umount ${luks_remdev}" || warn "Could not unmount ${luks_remdev}"
            sleep 0.2
        fi
    fi
}

format_devices_generic() {
    local autoresume_filename=$1
    shift
    local format=$* devnode fs options formatcmd=""
    if ! [ -f "$autoresume_profile_dir/${autoresume_filename}" ]; then
        for device in ${format}; do
            debug format_devices "formatting ${device}"
            devnode=$(echo "${device}" | cut -d: -f1)
            fs=$(echo "${device}" | cut -d: -f2)
            options=$(echo "${device}" | cut -d: -f3 | sed s/__/\ /g)
            case "${fs}" in
            swap)
                formatcmd="mkswap ${options} ${devnode}"
                ;;
            ext2)
                formatcmd="mke2fs ${options} ${devnode}"
                ;;
            ext3)
                #formatcmd="mkfs.ext3 -j -m 1 -O dir_index,filetype,sparse_super ${devnode}"
                formatcmd="mkfs.ext3 -j ${options} ${devnode}"
                ;;
            ext4)
                #mkfs.ext4dev -j -m 1 -O dir_index,filetype,sparse_super,extents,huge_file /dev/mapper/root
                formatcmd="mkfs.ext4 ${options} ${devnode}"
                ;;
            btrfs)
                formatcmd="mkfs.btrfs ${options} ${devnode}"
                ;;
            xfs)
                formatcmd="mkfs.xfs ${options} ${devnode}"
                ;;
            reiserfs | reiserfs3)
                formatcmd="mkreiserfs -q ${options} ${devnode}"
                ;;
            fat16)
                formatcmd="mkfs.vfat -F 16 ${options} ${devnode}"
                ;;
            fat32)
                formatcmd="mkfs.vfat -F 32 ${options} ${devnode}"
                ;;
            *)
                warn "don't know how to format ${devnode} as ${fs}"
                ;;
            esac
            if [ -n "${formatcmd}" ]; then
                sleep 0.1 # this helps not breaking formatting on VMs
                spawn "${formatcmd}" || die "Could not format ${devnode} with command: ${formatcmd}"
            fi
        done
    elif [ "${autoresume}" == "yes" ] && [ -f "$autoresume_profile_dir/${autoresume_filename}" ]; then
        # NOTE re run mkswap nothing else
        for device in ${format}; do
            debug format_devices "formatting ${device}"
            devnode=$(echo "${device}" | cut -d: -f1)
            fs=$(echo "${device}" | cut -d: -f2)
            options=$(echo "${device}" | cut -d: -f3 | sed s/__/\ /g)
            case "${fs}" in
            swap)
                formatcmd="mkswap ${options} ${devnode}"
                ;;
            esac
            if [ -n "${formatcmd}" ]; then
                sleep 0.1 # this helps not breaking formatting on VMs
                spawn "${formatcmd}" || die "Could not format ${devnode} with command: ${formatcmd}"
            fi
        done
    fi
}

format_devices() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    format_devices_generic 'format_devices' "${format}"
}

format_devices_luks() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    format_devices_generic 'format_devices_luks' "${format_luks}"
}

mount_local_partitions() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    if [ -z "${localmounts}" ]; then
        warn "no local mounts specified. this is a bit unusual, but you're the boss"
    else
        rm /tmp/install.mounts 2>/dev/null
        for mount in ${localmounts}; do
            debug mount_local_partitions "mount is ${mount}"
            local devnode ptype mountpoint mountopts
            devnode=$(echo "${mount}" | cut -d ':' -f1)
            ptype=$(echo "${mount}" | cut -d ':' -f2)
            mountpoint=$(echo "${mount}" | cut -d ':' -f3)
            mountopts=$(echo "${mount}" | cut -d ':' -f4)
            [ -n "${mountopts}" ] && mountopts="-o ${mountopts}"
            case "${ptype}" in
            swap)
                spawn "swapon ${devnode}" || warn "Could not activate swap ${devnode}"
                swapoffs="${devnode} "
                ;;
            ext2 | ext3 | ext4 | reiserfs | reiserfs3 | xfs | btrfs | vfat)
                echo "mount -t ${ptype} ${devnode} ${chroot_dir}${mountpoint} ${mountopts}" >>/tmp/install.mounts
                ;;
            esac
        done
        # make sure / is mounted first
        export LC_ALL=POSIX && sort -k5 /tmp/install.mounts | while read -r mount; do
            mkdir -p "$(echo "${mount}" | awk '{ print $5; }')"
            spawn "${mount}" || die "Could not mount with: ${mount}"
        done
    fi
}

mount_network_shares() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    if [ -n "${netmounts}" ]; then
        for mount in ${netmounts}; do
            debug mount_network_shares "mount is ${mount}"
            local export ntype mountpoint mountopts
            export=$(echo "${mount}" | cut -d '|' -f1)
            ntype=$(echo "${mount}" | cut -d '|' -f2)
            mountpoint=$(echo "${mount}" | cut -d '|' -f3)
            mountopts=$(echo "${mount}" | cut -d '|' -f4)
            [ -n "${mountopts}" ] && mountopts="-o ${mountopts}"
            case "${ntype}" in
            nfs)
                spawn "/etc/init.d/nfsmount start"
                mkdir -p "${chroot_dir}""${mountpoint}"
                spawn "mount -t nfs ${mountopts} ${export} ${chroot_dir}${mountpoint}" || die "Could not mount ${ntype}/${export}"
                ;;
            *)
                warn "mounting ${ntype} is not currently supported"
                ;;
            esac
        done
    fi
}

fetch_stage_tarball() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug fetch_stage_tarball "fetching stage tarball"
    if [ -n "${stage_uri}" ]; then
        local filename
        filename=$(get_filename_from_uri "${stage_uri}")
        fetch "${stage_uri}" "${chroot_dir}/${filename}" || die "Could not fetch stage tarball"
    fi
}

unpack_stage_tarball() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug unpack_stage_tarball "unpacking stage tarball"
    local tarball stage_name
    if [[ -n ${stage_uri} ]]; then
        tarball=$(get_filename_from_uri "${stage_uri}")
        local extension=${stage_uri##*.}

        if [ "$extension" == "bz2" ]; then
            spawn "tar xjpf ${chroot_dir}/${tarball} -C ${chroot_dir}" || die "Could not untar stage tarball"
        elif [ "$extension" == "gz" ]; then
            spawn "tar xzpf ${chroot_dir}/${tarball} -C ${chroot_dir}" || die "Could not untar stage tarball"
        elif [ "$extension" == "xz" ]; then
            spawn "tar Jxpf ${chroot_dir}/${tarball} -C ${chroot_dir}" || die "Could not untar stage tarball"
        elif [ "$extension" == "lzma" ]; then
            spawn "tar --lzma -xpf ${chroot_dir}/${tarball} -C ${chroot_dir}" || die "Could not untar stage tarball"
        fi
    elif [ -n "${stage_file}" ]; then
        spawn "cp ${stage_file} ${chroot_dir}" || die "Could not copy stage tarball"
        stage_name="$(basename "${stage_file}")"
        local extension=${stage_name##*.}

        if [ "$extension" == "bz2" ]; then
            spawn "tar xjpf ${chroot_dir}/${stage_name} -C ${chroot_dir}" || die "Could not untar stage tarball"
        elif [ "$extension" == "gz" ]; then
            spawn "tar xzpf ${chroot_dir}/${stage_name} -C ${chroot_dir}" || die "Could not untar stage tarball"
        elif [ "$extension" == "xz" ]; then
            spawn "tar Jxpf ${chroot_dir}/${stage_name} -C ${chroot_dir}" || die "Could not untar stage tarball"
        elif [ "$extension" == "lzma" ]; then
            spawn "tar --lzma -xpf ${chroot_dir}/${stage_name} -C ${chroot_dir}" || die "Could not untar stage tarball"
        fi
    fi
}

prepare_chroot() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug prepare_chroot "copying /etc/resolv.conf into chroot"
    spawn "cp /etc/resolv.conf ${chroot_dir}/etc/resolv.conf" || die "Could not copy /etc/resolv.conf into chroot"
    debug prepare_chroot "mounting proc"
    spawn "mount -t proc none ${chroot_dir}/proc" || die "Could not mount proc"
    debug prepare_chroot "bind-mounting /dev"
    spawn "mount -o rbind /dev ${chroot_dir}/dev/" || die "Could not rbind-mount /dev"
    debug prepare_chroot "bind-mounting /sys"
    [ -d "${chroot_dir}"/sys ] || mkdir "${chroot_dir}"/sys
    spawn "mount -o bind /sys ${chroot_dir}/sys" || die "Could not bind-mount /sys"
}

setup_fstab() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    echo -e "none\t/proc\tproc\tdefaults\t0 0\nnone\t/dev/shm\ttmpfs\tdefaults\t0 0" >"${chroot_dir}"/etc/fstab
    local devnode mtype mountpoint mountopts exportfs dump_pass="0 0"
    for mount in ${localmounts}; do
        debug setup_fstab "mount is ${mount}"
        devnode=$(echo "${mount}" | cut -d ':' -f1)
        mtype=$(echo "${mount}" | cut -d ':' -f2)
        mountpoint=$(echo "${mount}" | cut -d ':' -f3)
        mountopts=$(echo "${mount}" | cut -d ':' -f4)
        if [ "${mountpoint}" == "/" ]; then
            dump_pass="0 1"
        elif [ "${mountpoint}" == "/boot" ] || [ "${mountpoint}" == "/boot/" ]; then
            dump_pass="1 2"
        else
            dump_pass="0 0"
        fi
        echo -e "${devnode}\t${mountpoint}\t${mtype}\t${mountopts}\t${dump_pass}" >>"${chroot_dir}"/etc/fstab
    done
    for mount in ${netmounts}; do
        exportfs=$(echo "${mount}" | cut -d '|' -f1)
        mtype=$(echo "${mount}" | cut -d '|' -f2)
        mountpoint=$(echo "${mount}" | cut -d '|' -f3)
        mountopts=$(echo "${mount}" | cut -d '|' -f4)
        echo -e "${exportfs}\t${mountpoint}\t${mtype}\t${mountopts}\t0 0" >>"${chroot_dir}"/etc/fstab
    done
}

create_mdadmconf() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug create_mdadmconf "writing to /etc/mdadm.conf"
    for array in $(set | grep '^mdraid_' | cut -d= -f1 | sed -e 's:^mdraid_::' | sort); do
        if [ -n "${array}" ]; then
            local uuid
            uuid=$(eval "echo \${mduuid_${array}}")
            echo "ARRAY /dev/${array} uuid=${uuid}" >>"${chroot_dir}"/etc/mdadm.conf || die "Could not add array ${array} entry in /etc/mdadm.conf"
        fi
    done
}

create_dmcrypt() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug create_dmcrypt "writing to /etc/conf.d/dmcrypt"
    for device in ${luks}; do
        debug setup_luks "LUKSifying ${device}"
        local devicetmp luks_mapper cipher_name lukscmd=""
        devicetmp=$(echo "${device}"   | cut -d: -f1)
        luks_mapper=$(echo "${device}" | cut -d: -f2)
        cipher_name=$(echo "${device}" | cut -d: -f3)
        case ${luks_mapper} in
        swap)
            cat >>"${chroot_dir}"/etc/conf.d/dmcrypt <<EOF
swap=${luks_mapper}
source=${devicetmp}

EOF
            ;;
        root) ;;

        *)
            cat >>"${chroot_dir}"/etc/conf.d/dmcrypt <<EOF
target=${luks_mapper}
source=${devicetmp}
remdev=/dev/disk/by-uuid/$(get_uuid "${luks_remdev}")
key='${luks_key}'

EOF
            ;;
        esac
    done
}

create_makeconf() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug create_makeconf "writing to /etc/portage/make.conf"
    O=$IFS
    IFS=$(echo -en "\n\b")

    for var in $(set | grep -E '^makeconf_[A-Z]'); do
        var=$(echo "$var" | sed s/makeconf_//g | sed s/\'//g)
        local key val
        key=$(echo "$var" | cut -d= -f1)
        val=$(echo "$var" | cut -d= -f2)
        debug create_makeconf "appending ${key}=\"${val}\" to /etc/portage/make.conf"
        cat >>"${chroot_dir}"/etc/portage/make.conf <<EOF
${key}="${val}"
EOF
    done
    IFS=$O
}

set_locale() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug set_locale "configuring supported locales"
    # retrieve first locale in the list, and
    # match with first in supported locales to format the LANG
    local first_locale system_locale
    first_locale=$(echo "${locales}" | awk '{print $1}')
    system_locale=$(grep "^${first_locale}" /usr/share/i18n/SUPPORTED | head -n 1 | awk '{print $1}')
    echo "LANG=\"${system_locale}\"" >>"${chroot_dir}"/etc/env.d/02locale

    # remove existing locale.gen
    spawn "rm ${chroot_dir}/etc/locale.gen" || die "Could not rm ${chroot_dir}/etc/locale.gen"

    # overwrite with any matching locales
    for locale in ${locales}; do
        grep "^${locale}" /usr/share/i18n/SUPPORTED >>"${chroot_dir}"/etc/locale.gen
    done

    # make sure locale.gen is not overwritten automatically
    export CONFIG_PROTECT="/etc/locale.gen"
}

fetch_repo_tree() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug fetch_repo_tree "tree_type is ${tree_type}"
    if [ "${tree_type}" = "sync" ]; then
        spawn_chroot "emerge --sync" || die "Could not sync portage tree"
    elif [ "${tree_type}" = "snapshot" ]; then
        fetch "${portage_snapshot_uri}" "${chroot_dir}/$(get_filename_from_uri "${portage_snapshot_uri}")" || die "Could not fetch portage snapshot"
    elif [ "${tree_type}" = "webrsync" ]; then
        spawn_chroot "emerge-webrsync" || die "Could not emerge-webrsync"
    elif [ "${tree_type}" = "none" ]; then
        warn "'none' specified...skipping"
    else
        die "Unrecognized tree_type: ${tree_type}"
    fi

    if [ "${do_packages}" == "yes" ]; then
        notify "Fetching package repository tree"
        fetch "${portage_packages_uri}" "${chroot_dir}/$(get_filename_from_uri "${portage_packages_uri}")"
    fi
}

unpack_repo_tree() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug unpack_repo_tree "extracting packages tree"
    if [ "${tree_type}" = "snapshot" ]; then
        local tarball
        tarball=$(get_filename_from_uri "${portage_snapshot_uri}")
        local extension=${portage_snapshot_uri##*.}

        spawn "mkdir -p ${chroot_dir}/var/db/repos/gentoo" || die "Could not create portage directory"
        if [ "$extension" == "bz2" ]; then
            spawn "tar xjpf ${chroot_dir}/${tarball} --strip 1 -C ${chroot_dir}/var/db/repos/gentoo" || die "Could not untar portage tarball"
        elif [ "$extension" == "gz" ]; then
            spawn "tar xzpf ${chroot_dir}/${tarball} --strip 1 -C ${chroot_dir}/var/db/repos/gentoo" || die "Could not untar portage tarball"
        elif [ "$extension" == "xz" ]; then
            spawn "tar Jxpf ${chroot_dir}/${tarball} --strip 1 -C ${chroot_dir}/var/db/repos/gentoo" || die "Could not untar portage tarball"
        elif [ "$extension" == "lzma" ]; then
            spawn "tar --lzma -xpf ${chroot_dir}/${tarball} --strip 1 -C ${chroot_dir}/var/db/repos/gentoo" || die "Could not untar portage tarball"
        fi
    fi
# ========================================================================================================================================================================
# ========================================================================================================================================================================
# ========================================================================================================================================================================
# ========================================================================================================================================================================
# ========================================================================================================================================================================
# FIXME DO_PACKAGES REPLACE ME
    # tarball contains a ./packages/ snapshot from previous installs or binary host builds
    if [ "${do_packages}" == "yes" ] && [ -n "${portage_packages_uri}" ]; then    # <----------- replace me do_packages
        debug unpack_repo_tree "extracting packages tree"
        notify "Unpacking package repository tree"
        tarball=$(get_filename_from_uri "${portage_packages_uri}")
        local extension=${portage_packages_uri##*.}

        spawn "mkdir ${chroot_dir}/usr/portage/packages" || die "Could not create '/usr/portage/packages'"
        if [ "$extension" == "bz2" ]; then
            spawn "tar xjpf ${chroot_dir}/${tarball} -C ${chroot_dir}/usr/portage" || die "Could not untar portage tarball"
        elif [ "$extension" == "gz" ]; then
            spawn "tar xzpf ${chroot_dir}/${tarball} -C ${chroot_dir}/usr/portage" || die "Could not untar portage tarball"
        elif [ "$extension" == "xz" ]; then
            spawn "tar Jxpf ${chroot_dir}/${tarball} -C ${chroot_dir}/usr/portage" || die "Could not untar portage tarball"
        elif [ "$extension" == "lzma" ]; then
            spawn "tar --lzma -xpf ${chroot_dir}/${tarball} -C ${chroot_dir}/usr/portage" || die "Could not untar portage tarball"
        fi
    fi
}

set_profile() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug set_profile "setting profile with eselect to ${eselect_profile}"
    if [ -n "${eselect_profile}" ]; then
        spawn_chroot "eselect profile set ${eselect_profile}" || die "Could not set profile with eselect"
    fi
}

copy_kernel() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug copy_kernel "copying kernel binary ${kernel_binary} -> ${chroot_dir}/boot"
    # since genkernel might mount /boot we should do the same when copying to ${chroot_dir}/boot
    #check_chroot_fstab /boot && spawn_chroot "mount /boot"
    check_chroot_fstab /boot && spawn_chroot "[ -z \"\$(mount | grep /boot)\" ] && mount /boot"
    cp "${kernel_binary}" "${chroot_dir}/boot" || die "Could not copy precompiled kernel to ${chroot_dir}/boot"
    cp "${systemmap_binary}" "${chroot_dir}/boot" || warn "Could not copy precompiled System.map to ${chroot_dir}/boot"
}

copy_initramfs() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug copy_initramfs "copying initramfs binary ${initramfs_binary} -> ${chroot_dir}/boot"
    # user might not be using build_kernel nor copy_kernel
    check_chroot_fstab /boot && spawn_chroot "[ -z \"\$(mount | grep /boot)\" ] && mount /boot"
    cp "${initramfs_binary}" "${chroot_dir}/boot" || die "Could not copy precompiled initramfs to ${chroot_dir}/boot"
}

fetch_kernel_tarball() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug fetch_kernel_tarball "fetching kernel tarball ${kernel_uri}"
    if [ -n "${kernel_uri}" ]; then
        fetch "${kernel_uri}" "${chroot_dir}/$(get_filename_from_uri "${kernel_uri}")" || die "Could not fetch kernel tarball"
    fi
}

install_kernel_builder() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug install_kernel_builder "merging kernel builder: ${kernel_builder}"
    # pkg might already be installed if -a called
    check_emerge_installed_pkg "${kernel_builder}" ||
        spawn_chroot "emerge ${emerge_global_opts} ${kernel_builder}" || die "Could not emerge ${kernel_builder}"
}

build_kernel() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug build_kernel "compiling kernel sources: ${kernel_sources}"
    # pkg might already be installed if -a called
    check_emerge_installed_pkg "${kernel_sources}" ||
        spawn_chroot "emerge ${emerge_global_opts} ${kernel_sources}" || die "Could not emerge kernel sources"

    if [ "${kernel_builder}" == "genkernel" ]; then
        if [ -n "${kernel_config_uri}" ]; then
            fetch "${kernel_config_uri}" "${chroot_dir}/tmp/kconfig" || die "Could not fetch kernel config"
            spawn_chroot "genkernel --no-clean --kernel-config=/tmp/kconfig ${genkernel_kernel_opts} kernel" || die "Could not build custom kernel"
        elif [ -n "${kernel_config_file}" ]; then
            cp "${kernel_config_file}" "${chroot_dir}/tmp/kconfig" || die "Could not copy kernel config"
            spawn_chroot "genkernel --no-clean --kernel-config=/tmp/kconfig ${genkernel_kernel_opts} kernel" || die "Could not build custom kernel"
        else
            spawn_chroot "genkernel --no-clean ${genkernel_kernel_opts} kernel" || die "Could not build generic kernel"
        fi
    elif [ "${kernel_builder}" == "kigen" ]; then
        if [ -n "${kernel_config_uri}" ]; then
            fetch "${kernel_config_uri}" "${chroot_dir}/tmp/kconfig" || die "Could not fetch kernel config"
            spawn_chroot "kigen --dotconfig=/tmp/kconfig ${kigen_kernel_opts} kernel" || die "Could not build custom kernel"
        elif [ -n "${kernel_config_file}" ]; then
            cp "${kernel_config_file}" "${chroot_dir}/tmp/kconfig" || die "Could not copy kernel config"
            spawn_chroot "kigen --dotconfig=/tmp/kconfig ${kigen_kernel_opts} kernel" || die "Could not build custom kernel"
        else
            spawn_chroot "kigen ${kigen_kernel_opts} kernel" || die "Could not build generic kernel"
        fi
    fi
}

unpack_kernel_tarball() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug unpack_kernel_tarball "unpacking kernel tarball $(get_filename_from_uri "${kernel_uri}")"
    local kernel_filename
    kernel_filename=$(get_filename_from_uri "${kernel_uri}")
    local extension=${kernel_filename##*.}

    #check_chroot_fstab /boot && spawn_chroot "mount /boot"
    check_chroot_fstab /boot && spawn_chroot "[ -z \"\$(mount | grep /boot)\" ] && mount /boot"

    if [ "$extension" == "bz2" ] || [ "$extension" == "tbz2" ]; then
        spawn "tar xjpf ${chroot_dir}/${kernel_filename} -C ${chroot_dir}" || die "Could not untar kernel tarball"
    elif [ "$extension" == "gz" ] || [ "$extension" == "tgz" ]; then
        spawn "tar xzpf ${chroot_dir}/${kernel_filename} -C ${chroot_dir}" || die "Could not untar kernel tarball"
    elif [ "$extension" == "xz" ]; then
        spawn "tar Jxpf ${chroot_dir}/${kernel_filename} -C ${chroot_dir}" || die "Could not untar kernel tarball"
    elif [ "$extension" == "lzma" ]; then
        spawn "tar --lzma -xpf ${chroot_dir}/${kernel_filename} -C ${chroot_dir}" || die "Could not untar kernel tarball"
    fi
}

install_initramfs_builder() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug install_initramfs_builder "merging initramfs builder: ${initramfs_builder}"
    # initramfs builder might already be installed by install_kernel_builder
    check_emerge_installed_pkg "${initramfs_builder}" ||
        spawn_chroot "emerge ${emerge_global_opts} ${initramfs_builder}" || die "Could not emerge ${initramfs_builder}"
}

build_initramfs() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug build_initramfs "building initramfs binary"
    if [ "${initramfs_builder}" == "genkernel" ]; then
        spawn_chroot "genkernel ${genkernel_initramfs_opts} initramfs" || die "Could not build initramfs"
    elif [ "${initramfs_builder}" == "kigen" ]; then
        spawn_chroot "kigen ${kigen_initramfs_opts} initramfs" || die "Could not build initramfs"
    elif [ "${initramfs_builder}" == "dracut" ]; then
        spawn_chroot "dracut --force ${dracut_initramfs_opts}" || die "Could not build initramfs"
    else
        warn "No initramfs has been setup, skipping"
    fi
}

setup_network_post() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug setup_network_post "configuring network: ${net_devices}"
    if [ -n "${net_devices}" ]; then
        for net_device in ${net_devices}; do
            local device ipdhcp gateway
            device="$(echo "${net_device}"  | cut -d '|' -f1)"
            ipdhcp="$(echo "${net_device}"  | cut -d '|' -f2 | tr '[:upper:]' '[:lower:]')"
            gateway="$(echo "${net_device}" | cut -d '|' -f3)"
            case "${ipdhcp}" in
            "dhcp" | "noop" | "null" | "apipa")
                echo "config_${device}=( \"${ipdhcp}\" )" >>"${chroot_dir}"/etc/conf.d/net
                ;;
            *)
                echo -e "config_${device}=( \"${ipdhcp}\" )\nroutes_${device}=( \"default via ${gateway}\" )" >>"${chroot_dir}"/etc/conf.d/net
                ;;
            esac
            if [ ! -e "${chroot_dir}/etc/init.d/net.${device}" ]; then
                spawn_chroot "ln -s net.lo /etc/init.d/net.${device}" || die "Could not create symlink for device ${device}"
            fi
            spawn_chroot "rc-update add net.${device} default" || die "Could not add net.${device} to the default runlevel"
        done
    fi
}

setup_root_password() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug setup_root_password "writing root password"
    if [ -n "${root_password_hash}" ]; then
        # chpasswd does not support anymore '-e' option - http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=528610
        # use "usermod -p <encrypted_password> login" instead
        # here is how to generate the encrypted password - http://effbot.org/librarybook/crypt.htm
        # $ python
        # >>> import crypt; print crypt.crypt("<password>","<salt>")
        #spawn_chroot "echo 'root:${root_password_hash}' | chpasswd -e"  || die "Could not set root password"
        spawn_chroot "usermod -p '${root_password_hash}' root" || die "Could not set root password"
    elif [ -n "${root_password}" ]; then
        spawn_chroot "echo 'root:${root_password}' | chpasswd" || die "Could not set root password"
    fi
}

setup_timezone() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug setup_timezone "Setting timezone: ${timezone}"
    spawn "sed -i -n -e 's:clock=\".*\":clock=\"${timezone}\":' ${chroot_dir}/etc/conf.d/hwclock" || die "Could not adjust clock config in /etc/conf.d/hwclock"
    spawn "echo \"${timezone}\" > ${chroot_dir}/etc/timezone" || die "Could not set timezone in /etc/timezone"
    spawn "cp ${chroot_dir}/usr/share/zoneinfo/${timezone} ${chroot_dir}/etc/localtime" || die "Could not set timezone in /etc/localtime"
}

setup_keymap() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug setup_keymap "Setting keymap=${keymap} to /etc/conf.d/keymaps"
    spawn "/bin/sed -i 's:keymap=\"us\":keymap=\"${keymap}\":' ${chroot_dir}/etc/conf.d/keymaps" || die "Could not adjust keymap config in /etc/conf.d/keymaps"
}

setup_host() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug setup_host "Setting hostname=${hostname} to /etc/conf.d/hostname"
    spawn "/bin/sed -i 's:hostname=\"localhost\":hostname=\"${hostname}\":' ${chroot_dir}/etc/conf.d/hostname" || die "Could not adjust hostname config in /etc/conf.d/hostname"
}

setup_domain() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug setup_domain "Setting domain.name=${domain_name} to /etc/hosts"
    cat >"${chroot_dir}"/etc/hosts <<EOF
# IPv4 and IPv6 localhost aliases
127.0.0.1     ${hostname}.${domain_name} ${hostname} localhost.localdomain locahost
::1           localhost.localdoman localhost

# Other Networks and Hosts
EOF
}

install_extra_packages() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    if [ -z "${extra_packages}" ]; then
        debug install_extra_packages "no extra packages specified"
    else
        for o in ${extra_packages}; do
            # NOTE pkg might already be installed if -a called
            check_emerge_installed_pkg "${o}" ||
                spawn_chroot "emerge ${emerge_global_opts} ${o}" || die "Could not emerge extra package '${o}'"
        done
    fi
}

install_bootloader() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    [ "${bootloader}" == "" ] && die "bootloader not set, check profile"
    debug install_bootloader "merging bootloader: ${bootloader}"
    local accept_keywords=""
    local bootloader_ebuild=${bootloader}

    # make sure /boot is mounted if it should be
    check_chroot_fstab /boot && spawn_chroot "[ -z \"\$(mount | grep /boot)\" ] && mount /boot"

    # NOTE pkg might already be installed if -a called
    check_emerge_installed_pkg "${bootloader_ebuild}" ||
        spawn_chroot "ACCEPT_KEYWORDS=${accept_keywords} emerge ${emerge_global_opts} ${bootloader_ebuild}" || die "Could not emerge bootloader"
}

configure_bootloader() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug configure_bootloader "configuring bootloader: ${bootloader}"
    [ "${bootloader}" != "lilo" ]

    if isafunc configure_bootloader_"${bootloader}"; then
        configure_bootloader_"${bootloader}" || die "Could not configure bootloader ${bootloader}"
    else
        die "I don't know how to configure ${bootloader}"
    fi
}

add_and_remove_services() {
    [ "$(eval $(echo echo "\${do_${FUNCNAME}}"))" == "yes" ] || return

    debug add_and_remove_services "configuring startup services"
    local service runlevel
    if [ -n "${services_add}" ]; then
        for service_add in ${services_add}; do
            service="$(echo "${service_add}"  | cut -d '|' -f1)"
            runlevel="$(echo "${service_add}" | cut -d '|' -f2)"
            spawn_chroot "rc-update add ${service} ${runlevel}" || die "Could not add service ${service} to the ${runlevel} runlevel"
        done
    fi
    if [ -n "${services_del}" ]; then
        for service_del in ${services_del}; do
            service="$(echo "${service_del}"  | cut -d '|' -f1)"
            runlevel="$(echo "${service_del}" | cut -d '|' -f2)"
            spawn_chroot "rc-update del ${service} ${runlevel}"
        done
    fi
}

run_post_install_script() {
    if [ -n "${post_install_script_uri}" ]; then
        fetch "${post_install_script_uri}" "${chroot_dir}/var/tmp/post_install_script" || die "Could not fetch post-install script"
        chmod +x "${chroot_dir}/var/tmp/post_install_script"
        spawn_chroot "/var/tmp/post_install_script" || die "error running post-install script"
        spawn "rm ${chroot_dir}/var/tmp/post_install_script"
    elif isafunc post_install; then
        post_install || die "error running post_install()"
    else
        debug run_post_install_script "no post-install script set"
    fi
}

cleanup() {
    # NOTE override warn() when it should be mute
    [ -n "$1" ] && function warn() { false; }

    # NOTE makes sense to swapoff before all I think
    for swap in ${swapoffs}; do
        spawn "swapoff ${swap}" || warn "Could not deactivate swap on ${swap}"
    done

    if [ -f "/proc/mounts" ]; then
        # FIXME issue here is that we need to sort -udr the output
        #       or we end up trying unmounting chroot_dir first which will fail
        #       therefore leaving zombie mount points after cleanup
 #        grep "${chroot_dir}" </proc/mounts | while read -ra mnt; do
 #            spawn "echo umount ${mnt[1]} || warn Could not unmount ${mnt[1]}"
 #            spawn "umount ${mnt[1]}" || warn "Could not unmount ${mnt[1]}"
 #            sleep 0.2
 #        done

        # FIXED? this sorts the output of grep chroot_dir /proc/mounts
        #        so that hopefully /mnt/gentoo comes last
        # FIXME2 can I do the same with umount -lR $mountpoint?
        mapfile -t l <<< $(grep ${chroot_dir} </proc/mounts | cut -d' ' -f2)
        readarray -t sorted < <(for a in "${l[@]}"; do echo "$a"; done | sort -udr)
        for a in "${sorted[@]}"; do
            if [ -d "${a}" ]; then
                spawn "umount ${a}" || warn "Could not unmount ${a}"
            fi
        done
    fi

    # NOTE let lvm cleanup before luks
    # FIXME what about luks inside lvm??
    for volgroup in $(set | grep '^lvm_volgroup_' | cut -d= -f1 | sed -e 's:^lvm_volgroup_::' | sort); do
        spawn "vgchange -a n ${volgroup}" || warn "Could not remove vg ${volgroup}"
        sleep 0.2
    done
    for luksdev in $(set | grep '^luks=' | cut -d= -f2); do
        luksdev=$(echo "${luksdev}" | cut -d: -f2)
        spawn "cryptsetup remove ${luksdev}" || warn "Could not remove luks device /dev/mapper/${luksdev}"
        sleep 0.2
    done

    # NOTE possible leftovers like /mnt/gentoo/boot that gets mounted twice, not needed anymore but does no harm
    #if [ -f "/proc/mounts" ]; then
    #    for mnt in $(awk '{ print $2; }' /proc/mounts | grep ^${chroot_dir} | sort -ur); do
    #        spawn "umount ${mnt}" || warn "Could really not unmount ${mnt}"
    #        sleep 0.2
    #    done
    #fi
    # NOTE: let mdadm clean up after lvm AND luks; if all were used, shutdown layers, top->bottom: lvm->luks->mdadm
    for array in $(set | grep '^mdraid_' | cut -d= -f1 | sed -e 's:^mdraid_::' | sort); do
        spawn "mdadm --manage --stop /dev/${array}" || warn "Could not stop mdraid array ${array}"
        sleep 0.2
    done

    # NOTE  this is warn() as defined in modules/output.sh
    # FIXME find another way, dont overwrite here, it's not its place
    #       rather pass skip extra param to cleanup and let warn read skip, if yes then let warn cancel its verbosity
    [ -n "$1" ] && function warn() {
        local msg=$1
        [ "${verbose}" == "yes" ] && echo -e " ${WARN}***${NORMAL} ${msg}" >&2
        log "Warning: ${msg}"
    }
}

starting_cleanup() {
    cleanup quiet
}

finishing_cleanup() {
    [ "${verbose}" == "yes" ] && notify "Cleaning up ${autoresume_profile_name}'s autoresume points"
    if ! spawn "rm -rf ${autoresume_profile_dir}/"; then
        warn "Unable to remove ${autoresume_profile_name}'s autoresume points"
    fi
    if [ -f "${logfile}" ] && [ -d "${chroot_dir}" ]; then
        spawn "cp ${logfile} ${chroot_dir}/root/$(basename "${logfile}")" || warn "Could not copy install logfile into chroot"
    fi
    cleanup
    echo
}

failure_cleanup() {
    if [ -f "${logfile}" ]; then
        spawn "mv ${logfile} ${logfile}.failed" || warn "Could not move ${logfile} to ${logfile}.failed"
    fi
    cleanup
    echo
    exit 1
}

trap_cleanup() {
    echo
    false
}
