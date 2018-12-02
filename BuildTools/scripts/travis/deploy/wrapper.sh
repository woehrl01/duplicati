#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/../shared.sh"


parse_options "$@"
load_mono
setup_copy_cache
travis_mark_begin "CREATING PACKAGE"
deploy_in_docker
travis_mark_end "CREATING PACKAGE"