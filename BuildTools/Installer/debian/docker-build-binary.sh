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
DATE_STAMP=$(LANG=C date -R)

if [ ! -f "$ZIPFILE" ]; then
	echo "Please provide the filename of an existing zip build as the first argument"
	exit
fi

if [ -d "${SCRIPT_DIR}/${DIRNAME}" ]; then
	rm -rf "${SCRIPT_DIR}/${DIRNAME}"
fi

unzip -q -d "${SCRIPT_DIR}/${DIRNAME}" "$ZIPFILE"

. "${SCRIPT_DIR}/../../scripts/common.sh"
install_oem_files "${SCRIPT_DIR}" "${SCRIPT_DIR}/${DIRNAME}"

cp -R "${SCRIPT_DIR}/debian" "${SCRIPT_DIR}/${DIRNAME}"
cp "${SCRIPT_DIR}/bin-rules.sh" "${SCRIPT_DIR}/${DIRNAME}/debian/rules"
sed -e "s;%VERSION%;$VERSION;g" -e "s;%DATE%;$DATE_STAMP;g" "${SCRIPT_DIR}/debian/changelog" > "${SCRIPT_DIR}/${DIRNAME}/debian/changelog"

touch "${SCRIPT_DIR}/${DIRNAME}/releasenotes.txt"

docker build -t "duplicati/debian-build:latest" - < "${SCRIPT_DIR}/Dockerfile.build"

# Weirdness with time not being synced in Docker instance
sleep 5
docker run  --workdir "/builddir/${DIRNAME}" --volume ${SCRIPT_DIR}:/builddir:rw "duplicati/debian-build:latest" dpkg-buildpackage
docker run  --workdir "/builddir/${DIRNAME}" --volume ${SCRIPT_DIR}:/builddir:rw "duplicati/debian-build:latest" rm -rf /builddir/${DIRNAME}

for filename in "duplicati_${VERSION}-1_amd64.changes" "duplicati_${VERSION}-1.dsc"  "duplicati_${VERSION}-1.tar.gz"
do
    if [ -f "${SCRIPT_DIR}/${filename}" ]; then
        rm -f "${SCRIPT_DIR}/${filename}"
    fi
done
