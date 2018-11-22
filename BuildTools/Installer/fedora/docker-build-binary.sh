#!/bin/bash

quit_on_error() {
    echo "Error on line $1, stopping build of installer(s)."
    exit 1
}

set -eE
trap 'quit_on_error $LINENO' ERR

ZIPFILE=$1
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
FILENAME=$(basename $ZIPFILE)
DIRNAME=$(echo "${FILENAME}" | cut -d "_" -f 1)
VERSION=$(echo "${DIRNAME}" | cut -d "-" -f 2)
BUILDDATE=$(date +%Y%m%d)
BUILDTAG_RAW=$(echo "${FILENAME}" | cut -d "." -f 1-4 | cut -d "-" -f 2-4)
BUILDTAG="${BUILDTAG_RAW//-}"


if [ ! -f "$1" ]; then
	echo "Please provide the filename of an existing zip build as the first argument"
	exit
fi

echo "BUILDTAG: ${BUILDTAG}"
echo "Version: ${VERSION}"
echo "Builddate: ${BUILDDATE}"
echo "Dirname: ${DIRNAME}"

if [ -d "${SCRIPT_DIR}/${DIRNAME}" ]; then
	rm -rf "${SCRIPT_DIR}/${DIRNAME}"
fi

unzip -q -d "${SCRIPT_DIR}/${DIRNAME}" "$ZIPFILE"

cp ${SCRIPT_DIR}/../debian/*-launcher.sh "${SCRIPT_DIR}/${DIRNAME}"
cp ${SCRIPT_DIR}/../debian/duplicati.png "${SCRIPT_DIR}/${DIRNAME}"
cp ${SCRIPT_DIR}/../debian/duplicati.desktop "${SCRIPT_DIR}/${DIRNAME}"

. "${SCRIPT_DIR}/../../scripts/common.sh"
install_oem_files "${SCRIPT_DIR}" "${SCRIPT_DIR}/${DIRNAME}"

tar -cjf "${SCRIPT_DIR}/${DIRNAME}.tar.bz2" -C ${SCRIPT_DIR} "${DIRNAME}"
rm -rf "${SCRIPT_DIR}/${DIRNAME}"

RPMBUILD="${SCRIPT_DIR}/${DIRNAME}-rpmbuild"
if [ -d "${RPMBUILD}" ]; then
    rm -rf "${RPMBUILD}"
fi

mkdir -p "${RPMBUILD}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

mv "${SCRIPT_DIR}/${DIRNAME}.tar.bz2" "${RPMBUILD}/SOURCES/"
cp "${SCRIPT_DIR}"/duplicati.xpm "${RPMBUILD}/SOURCES/"
cp "${SCRIPT_DIR}"/make-binary-package.sh "${RPMBUILD}/SOURCES/duplicati-make-binary-package.sh"
cp "${SCRIPT_DIR}"/duplicati-install-recursive.sh "${RPMBUILD}/SOURCES/duplicati-install-recursive.sh"
cp "${SCRIPT_DIR}"/duplicati.service "${RPMBUILD}/SOURCES/duplicati.service"
cp "${SCRIPT_DIR}"/duplicati.default "${RPMBUILD}/SOURCES/duplicati.default"

echo "%global _builddate ${BUILDDATE}" > "${RPMBUILD}/SOURCES/duplicati-buildinfo.spec"
echo "%global _buildversion ${VERSION}" >> "${RPMBUILD}/SOURCES/duplicati-buildinfo.spec"
echo "%global _buildtag ${BUILDTAG}" >> "${RPMBUILD}/SOURCES/duplicati-buildinfo.spec"

docker build -t "duplicati/fedora-build:latest" - < "${SCRIPT_DIR}/Dockerfile.build"

# Weirdness with time not being synced in Docker instance
sleep 5
docker run  \
    --workdir "/buildroot" \
    --volume "${SCRIPT_DIR}":"/buildroot":"rw" \
    --volume "${RPMBUILD}":"/root/rpmbuild":"rw" \
    "duplicati/fedora-build:latest" \
    rpmbuild -bb duplicati-binary.spec

cp "${RPMBUILD}/RPMS/noarch/"*.rpm ${SCRIPT_DIR}/

docker run  \
    --workdir "/buildroot" \
    --volume "/home/hendrik/projects/duplicati/BuildTools/Installer/fedora":"/buildroot":"rw" \
    "duplicati/fedora-build:latest" \
    rm -rf /buildroot/${DIRNAME}-rpmbuild
