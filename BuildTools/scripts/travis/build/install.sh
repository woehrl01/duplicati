#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/../shared.sh"

function build_install () {
    eval nuget restore Duplicati.sln $IF_QUIET_SUPPRESS_OUTPUT

    if [ ! -d "${DUPLICATI_ROOT}"/packages/SharpCompress.0.18.2 ]; then
        ln -s "${DUPLICATI_ROOT}"/packages/sharpcompress.0.18.2 "${DUPLICATI_ROOT}"/packages/SharpCompress.0.18.2
    fi
}

parse_options $@
build_install
