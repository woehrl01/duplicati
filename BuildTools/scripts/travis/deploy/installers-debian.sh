#!/bin/bash
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/utils.sh"

function build_installer () {



	echo "Building Debian deb"

    ZIPFILE="${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"

    echo $ZIPFILE
    echo $RELEASE_VERSION
    DIRNAME=$(echo "${RELEASE_FILE_NAME}" | cut -d "_" -f 1)
	DEBNAME="duplicati_${RELEASE_VERSION}-1_all.deb"
    DATE_STAMP=$(LANG=C date -R)

    unzip -q -d "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}" "$ZIPFILE"

    install_oem_files "${DUPLICATI_ROOT}/BuildTools/Installer/debian/" "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}"

    cp -R "${DUPLICATI_ROOT}/BuildTools/Installer/debian/debian" "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}"
    cp "${DUPLICATI_ROOT}/BuildTools/Installer/debian/bin-rules.sh" "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}/debian/rules"
    sed -e "s;%VERSION%;${RELEASE_VERSION};g" -e "s;%DATE%;$DATE_STAMP;g" "${DUPLICATI_ROOT}/BuildTools/Installer/debian/debian/changelog" > "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}/debian/changelog"

    touch "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}/releasenotes.txt"

    docker build -t "duplicati/debian-build:latest" - < "${DUPLICATI_ROOT}/BuildTools/Installer/debian/Dockerfile.build"

    # Weirdness with time not being synced in Docker instance
    sleep 5
    docker run --workdir "/builddir/${DIRNAME}" --volume ${DUPLICATI_ROOT}/BuildTools/Installer/debian:/builddir:rw "duplicati/debian-build:latest" dpkg-buildpackage

	mv "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DEBNAME}" "${UPDATE_TARGET}"

	echo "Done building deb package"
}


parse_options "$@"

build_installer
