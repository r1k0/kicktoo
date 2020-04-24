isafunc() {
    local func=$1

    declare -f "${func}" >/dev/null
    local exitcode=$?
    debug isafunc "${func} with exitcode $exitcode"

    return ${exitcode}
}

autoresume_runstep() {
    local func=${1}
    local autoresume_step_file="${autoresume_profile_dir}/${func}"

    local doskip="no"
    [ -n "${2}" ] && doskip="yes"

    if ! [ -f "${autoresume_step_file}" ] && [ "${autoresume}" == "yes" ]; then
        [ ${doskip} == "yes" ] &&
            debug autoresume_runstep "SKIPPING ${func}"

        [ ${doskip} == "no" ] && ${func}
        # NOTE do not setup autoresume points for the following runsteps:
        #    starting_cleanup     (since we do cleanup on start)
        #    finishing_cleanup    (since it makes no sense resuming the last runstep)
        #    failure_cleanup      (since it makes no sense)
        #    get_latest_stage_uri (since this one sets stage_uri)
        [ "${func}" != "finishing_cleanup"    ] &&
        [ "${func}" != "starting_cleanup"     ] &&
        [ "${func}" != "failure_cleanup"      ] &&
        [ "${func}" != "get_latest_stage_uri" ] &&
            touch "${autoresume_step_file}"
    else
        # NOTE we want to run these runsteps anyway, don't skip
        #   mount*
        #   prepare_chroot
        if [ "${func}" == "format_devices" ]; then
            spawn "rm -f ${autoresume_profile_dir}/mount*" || warn "Cannot remove ${autoresume_profile_dir}/mount* resume points, should not autoresume"
        fi

# FIXME shouldnt we add format_devices_luks too?
# FIXME2 seems not according to comment below: but shouldnt add format_devices_luks too??

        if [ "${func}" == "unpack_stage_tarball" ]; then
            spawn "rm -f ${autoresume_profile_dir}/prepare_chroot" || warn "Cannot remove ${autoresume_profile_dir}/prepare_chroot resume points, should not autoresume"
        fi

        # NOTE we want to run these nonetheless and let them handle the autoresume by themselves
        #   setup_mdraid
        #   setup_lvm
        #   setup_luks
        #   format_devices (this is only for the swap, we re run mkswap on autoresume but that's all)
        if [ "${func}" == "setup_mdraid"        ] ||
           [ "${func}" == "setup_lvm"           ] ||
           [ "${func}" == "format_devices"      ] ||
           [ "${func}" == "format_devices_luks" ] ||
           [ "${func}" == "setup_luks"     ]; then
              ${func} # <<<
        else
            local dofunc=$(eval $(echo echo "\${do_${func}}"))
            if [ "${dofunc}" != "no" ]; then
                echo -ne " -> ${BOLD}resumed${NORMAL}"
            fi
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

    if isafunc pre_"${func}"; then
        echo -en " >>>   ${BOLD}pre${NORMAL}_${func}"
        debug runstep "executing pre-hook for ${func}"
        if [ "${autoresume}" = "yes" ]; then
            autoresume_runstep pre_"${func}" || pre_"${func}" && echo
        fi
    fi

    local dofunc=$(eval $(echo echo "\${do_${func}}"))
    if [ "${skipfunc}" != "yes" ] || [ "${skipfunc}" == "no" ] && [ "${dofunc}"  != "no" ]; then
#        echo -e " ${GOOD}>>>${NORMAL} ${descr}"
        echo -en " ${GOOD}>>>${NORMAL} ${BOLD}${func}${NORMAL}"
        log "${descr}"

        debug runstep "executing main for ${func}"
        if [ "${autoresume}" = "yes" ]; then
            autoresume_runstep "${func}" || ${func} && echo # <<<
        fi
    else
        debug runstep "SKIPPING step ${func}"
        echo -e " ${WARN}>>>${NORMAL} ${func} -> skipped"
        if [ "${autoresume}" = "yes" ]; then
            autoresume_runstep "${func}" skip
        fi
    fi

    if isafunc post_"${func}"; then
        echo -en " >>>   ${BOLD}post${NORMAL}_${func}"
        debug runstep "executing post-hook for ${func}"
        if [ "${autoresume}" = "yes" ]; then
            autoresume_runstep post_"${func}" || post_"${func}" && echo
        fi
    fi
}
