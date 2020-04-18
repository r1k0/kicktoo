server_init() {
    if [ -n "$(echo "${server}" | grep :)" ]; then
        server_host=$(echo "${server}" | cut -d : -f 1)
        server_port=$(echo "${server}" | cut -d : -f 2)
    else
        server_host="${server}"
    fi

    mac_address=$(get_mac_address)
    if [ -z "${server_port}" ]; then
        server_port=1337
    fi
}

server_send_request() {
    local command=$1
    local args=$2

    fetch "kicktoo:///${command}?${args}" "/tmp/server_response"
    cat /tmp/server_response
}

server_get_profile() {
    local profile_uri=$(server_send_request "get_profile_path" "mac=${mac_address}")

    # NOTE when --verbose is passed the output gets appended before too which is bad
    #      so always make sure we stripped out the crap by always getting last field
    #      do not quote ${profile_uri} as awk wont save the last field
    profile_uri=$(echo ${profile_uri} | awk '{print $NF}')  # | grep -oE '[^ ]+$')

    if [ -z "${profile_uri}" ]; then
        warn "error in response from server...could not retrieve profile URI"
        return 1
    else
        debug server_get_profile "profile URI is ${profile_uri}"
        fetch "${profile_uri}" "/tmp/kicktoo_profile"
        local curl_exitcode=$?
        if [ "${curl_exitcode}" -ne 0 -a "${curl_exitcode}" -ne 33 ]; then
            error "could not fetch profile"
            exit 1
        fi
        notify "Fetched profile from ${profile_uri}"
    fi
}
