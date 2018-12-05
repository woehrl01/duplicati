#!/bin/bash
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/utils.sh"

function build_installer () {
    ZIPFILE="${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"
    DIRNAME=$(echo "${RELEASE_FILE_NAME}" | cut -d "_" -f 1)
    RPMBUILD="${fedora_installer_dir}/${DIRNAME}-rpmbuild"
    BUILDDATE=$(date +%Y%m%d)
    BUILDTAG_RAW=$(echo "${RELEASE_FILE_NAME}" | cut -d "." -f 1-4 | cut -d "-" -f 2-4)
    BUILDTAG="${BUILDTAG_RAW//-}"

    fedora_installer_dir="${DUPLICATI_ROOT}/BuildTools/Installer/fedora/"

    unzip -q -d "${fedora_installer_dir}/${DIRNAME}" "$ZIPFILE"

    cp ${fedora_installer_dir}/../debian/*-launcher.sh "${fedora_installer_dir}/${DIRNAME}"
    cp ${fedora_installer_dir}/../debian/duplicati.png "${fedora_installer_dir}/${DIRNAME}"
    cp ${fedora_installer_dir}/../debian/duplicati.desktop "${fedora_installer_dir}/${DIRNAME}"

    install_oem_files "${fedora_installer_dir}/" "${fedora_installer_dir}/${DIRNAME}"
    tar -cjf "${fedora_installer_dir}/${DIRNAME}.tar.bz2" -C ${fedora_installer_dir} "${fedora_installer_dir}/${DIRNAME}"

    mkdir -p "${RPMBUILD}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

    mv "${fedora_installer_dir}/${DIRNAME}.tar.bz2" "${RPMBUILD}/SOURCES/"
    cp "${fedora_installer_dir}"/duplicati.xpm "${RPMBUILD}/SOURCES/"
    cp "${fedora_installer_dir}"/make-binary-package.sh "${RPMBUILD}/SOURCES/duplicati-make-binary-package.sh"
    cp "${fedora_installer_dir}"/duplicati-install-recursive.sh "${RPMBUILD}/SOURCES/duplicati-install-recursive.sh"
    cp "${fedora_installer_dir}"/duplicati.service "${RPMBUILD}/SOURCES/duplicati.service"
    cp "${fedora_installer_dir}"/duplicati.default "${RPMBUILD}/SOURCES/duplicati.default"

    echo "%global _builddate ${BUILDDATE}" > "${RPMBUILD}/SOURCES/duplicati-buildinfo.spec"
    echo "%global _buildversion ${VERSION}" >> "${RPMBUILD}/SOURCES/duplicati-buildinfo.spec"
    echo "%global _buildtag ${BUILDTAG}" >> "${RPMBUILD}/SOURCES/duplicati-buildinfo.spec"

    docker build -t "duplicati/fedora-build:latest" - < "${fedora_installer_dir}/Dockerfile.build"

    # Weirdness with time not being synced in Docker instance
    sleep 5
    docker run  \
        --workdir "/buildroot" \
        --volume "${WORKING_DIR}/BuildTools/Installer/fedora}":"/buildroot":"rw" \
        --volume "${WORKING_DIR}/BuildTools/Installer/fedora/${DIRNAME}-rpmbuild":"/root/rpmbuild":"rw" \
        "duplicati/fedora-build:latest" \
        rpmbuild -bb duplicati-binary.spec

    cp "${RPMBUILD}/RPMS/noarch/"*.rpm ${UPDATE_TARGET}/
}

parse_options "$@"

travis_mark_begin "BUILDING FEDORA PACKAGE"
build_installer
travis_mark_end "BUILDING FEDORA PACKAGE"