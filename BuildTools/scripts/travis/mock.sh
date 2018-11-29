#!/bin/bash
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/shared.sh"


TRAVIS_BUILD_DIR="${SCRIPT_DIR}/../../../"
BUILD_CACHE="${TRAVIS_BUILD_DIR}/../build_cache"
TEST_DIR=${TRAVIS_BUILD_DIR}/../test
#${TRAVIS_BUILD_DIR}/BuildTools/scripts/travis/build/wrapper.sh --repodir "${TRAVIS_BUILD_DIR}" --cache "$BUILD_CACHE"
# ${TRAVIS_BUILD_DIR}/BuildTools/scripts/travis/unittest/wrapper.sh --categories BulkNormal --data data.zip --cache "$BUILD_CACHE" --testdir "$TEST_DIR"
${TRAVIS_BUILD_DIR}/BuildTools/scripts/travis/deploy/wrapper.sh --cache "$BUILD_CACHE"
