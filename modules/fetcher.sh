#!/usr/bin/env bash

get_filename_from_uri() {
    local uri=$1

    basename "${1}"
}

fetch() {
    local uri=$1
    local localfile=$2

    debug fetch "Fetching URL ${uri} to ${localfile}"
    spawn "curl -L -S \"${uri}\" -o ${localfile} -C -"
    local curl_exitcode=$?
    debug fetch "exit code from curl was ${curl_exitcode}"
    return ${curl_exitcode}
}
