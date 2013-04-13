isafunc() {
    local func=$1

    declare -f ${func} > /dev/null
    local exitcode=$?
#    debug isafunc "${func} with exitcode $exitcode"
    return ${exitcode}
}

autoresume_runstep() {
    local func="${1}"
    local autoresume_step_file="${autoresume_profile_dir}/${func}"

    local doskip="no"
    [ -n "${2}" ] && doskip="yes"

    if ! [ -f "${autoresume_step_file}" ] && [ "${autoresume}" == "yes" ] ; then
        [ ${doskip} == "yes" ] && \
        debug autoresume_runstep "SKIPPING ${func}"

        [ ${doskip} == "no" ] && ${func}
        # NOTE do not setup autoresume points for the following runsteps: 
        #    starting_cleanup     (since we do cleanup on start)
        #    finishing_cleanup    (since it makes no sense resuming the last runstep)
        #    failure_cleanup      (since it makes no sense)
        #    get_latest_stage_uri (since this one sets stage_uri)
        [ "${func}" != "finishing_cleanup" ]    && \
        [ "${func}" != "starting_cleanup" ]     && \
        [ "${func}" != "failure_cleanup" ]      && \
        [ "${func}" != "get_latest_stage_uri" ] && \
        touch ${autoresume_step_file}
    else
        # NOTE we want to run these runsteps anyway, don't skip
        #   mount*
        #   prepare_chroot
        if [ "${func}" == "format_devices" ]; then
            spawn "rm -f ${autoresume_profile_dir}/mount*" || warn "Cannot remove ${autoresume_profile_dir}/mount* resume points, should not autoresume"
        fi
        if [ "${func}" == "unpack_stage_tarball" ]; then
            spawn "rm -f ${autoresume_profile_dir}/prepare_chroot" || warn "Cannot remove ${autoresume_profile_dir}/prepare_chroot resume points, should not autoresume"
        fi
       
        # NOTE we want to run these nonetheless and let them handle the autoresume by themselves
        #   setup_mdraid
        #   setup_lvm
        #   setup_luks
        #   format_devices (this is only for the swap, we re run mkswap on autoresume but that's all)
        if [ "${func}" == "setup_mdraid" ]   || \
           [ "${func}" == "setup_lvm" ]      || \
           [ "${func}" == "format_devices" ] || \
           [ "${func}" == "setup_luks" ]; then
            ${func} # <<<
        else
            notify "  >>> Done, skipping"
        fi
    fi
}

runstep() {
    local func=$1
    local descr=$2
    local skipfunc=$(eval $(echo echo "\${skip_${func}}"))

    if [ "${skipfunc}" != "1" ]; then
        if [ -n "${server}" ]; then
            server_send_request "update_status" "func=${func}&descr=$(echo "${descr}" | sed -e 's: :+:g')"
        fi
    fi

    if $(isafunc pre_${func}); then
        echo -e "  > pre_${func}()"
        debug runstep "executing pre-hook for ${func}"
        [ ${autoresume} = "yes" ] && autoresume_runstep pre_${func} || pre_${func}
    fi

    if [ "${skipfunc}" != "1" ]; then
#        notify "${descr}"
        echo -e " ${GOOD}>>>${NORMAL} ${descr}"
        log "${descr}"

        debug runstep "executing main for ${func}"
        [ ${autoresume} = "yes" ] && autoresume_runstep ${func} || ${func} # <<<

    else
        debug runstep "skipping step ${func}"
        [ ${autoresume} = "yes" ] && autoresume_runstep ${func} skip
    fi

    if $(isafunc post_${func}); then
        echo -e "  > post_${func}()"
        debug runstep "executing post-hook for ${func}"
        [ ${autoresume} = "yes" ] && autoresume_runstep post_${func} || post_${func}
    fi
}


