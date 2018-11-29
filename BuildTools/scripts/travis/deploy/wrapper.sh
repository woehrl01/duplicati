#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/../shared.sh"


parse_options "$@"
load_mono
setup_copy_cache
deploy_in_docker