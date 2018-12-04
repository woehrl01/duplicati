#!/bin/bash
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/utils.sh"

ZIPFILE=$1
FILENAME=$(basename $ZIPFILE)
DIRNAME=$(echo "${FILENAME}" | cut -d "_" -f 1)
VERSION=$(echo "${DIRNAME}" | cut -d "-" -f 2)
DATE_STAMP=$(LANG=C date -R)

unzip -q -d "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}" "$ZIPFILE"

install_oem_files "${DUPLICATI_ROOT}/BuildTools/Installer/debian/" "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}"

cp -R "${DUPLICATI_ROOT}/BuildTools/Installer/debian/debian" "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}"
cp "${DUPLICATI_ROOT}/BuildTools/Installer/debian/bin-rules.sh" "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}/debian/rules"
sed -e "s;%VERSION%;$VERSION;g" -e "s;%DATE%;$DATE_STAMP;g" "${DUPLICATI_ROOT}/BuildTools/Installer/debian/debian/changelog" > "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}/debian/changelog"

touch "${DUPLICATI_ROOT}/BuildTools/Installer/debian/${DIRNAME}/releasenotes.txt"

docker build -t "duplicati/debian-build:latest" - < "${DUPLICATI_ROOT}/BuildTools/Installer/debian/Dockerfile.build"

# Weirdness with time not being synced in Docker instance
sleep 5
docker run --workdir "/builddir/${DIRNAME}" --volume ${DUPLICATI_ROOT}/BuildTools/Installer/debian:/builddir:rw "duplicati/debian-build:latest" dpkg-buildpackage
