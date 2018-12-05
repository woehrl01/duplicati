#!/bin/bash
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/utils.sh"

function build_installer () {
    ZIPFILE="${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"
    DIRNAME=$(echo "${RELEASE_FILE_NAME}" | cut -d "_" -f 1)
	DEBNAME="duplicati_${RELEASE_VERSION}-1_all.deb"
    DATE_STAMP=$(LANG=C date -R)
    debian_installer_dir="${DUPLICATI_ROOT}/BuildTools/Installer/debian/"

    unzip -q -d "${debian_installer_dir}/${DIRNAME}" "$ZIPFILE"

    install_oem_files "${debian_installer_dir}/" "${debian_installer_dir}/${DIRNAME}"

    cp -R "${debian_installer_dir}/debian/debian" "${debian_installer_dir}/${DIRNAME}"
    cp "${debian_installer_dir}/debian/bin-rules.sh" "${debian_installer_dir}/${DIRNAME}/debian/rules"
    sed -e "s;%VERSION%;${RELEASE_VERSION};g" -e "s;%DATE%;$DATE_STAMP;g" "${debian_installer_dir}/debian/changelog" > "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}/debian/changelog"

    touch "${debian_installer_dir}/${DIRNAME}/releasenotes.txt"

    docker build -t "duplicati/debian-build:latest" - < "${debian_installer_dir}/Dockerfile.build"

    # Weirdness with time not being synced in Docker instance
    sleep 5

    docker run --workdir "/builddir/${DIRNAME}" --volume ${WORKING_DIR}/BuildTools/Installer/debian/:/builddir:rw "duplicati/debian-build:latest" dpkg-buildpackage

	mv "${debian_installer_dir}/${DEBNAME}" "${UPDATE_TARGET}"
}

parse_options "$@"

travis_mark_begin "BUILDING DEBIAN PACKAGE"
build_installer
travis_mark_end "BUILDING DEBIAN PACKAGE"
