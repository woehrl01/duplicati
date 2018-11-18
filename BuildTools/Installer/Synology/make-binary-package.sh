#!/bin/bash


quit_on_error() {
    echo "Error on line $1, stopping build of installer(s)."
    exit 1
}

set -eE
trap 'quit_on_error $LINENO' ERR



ZIPFILE=$1
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
FILENAME=$(basename $1)
DIRNAME="${SCRIPT_DIR}"/$(echo "${FILENAME}" | cut -d "_" -f 1)
VERSION=$(echo "${DIRNAME}" | cut -d "-" -f 2)
DATE_STAMP=$(LANG=C date -R)
BASE_FILE_NAME="${FILENAME%.*}"
TMPDIRNAME="${SCRIPT_DIR}/${BASE_FILE_NAME}-extract"
MONO=/Library/Frameworks/Mono.framework/Commands/mono
GPG_KEYFILE="${HOME}/.config/signkeys/Duplicati/updater-gpgkey.key"

if [ ! -f "$ZIPFILE" ]; then
	echo "Please provide the filename of an existing zip build as the first argument"
	exit
fi


rm -rf "${DIRNAME}"

if [ -d "${TMPDIRNAME}" ]; then
    rm -rf "${TMPDIRNAME}"
fi

rm -rf "${SCRIPT_DIR}/package.tgz"
rm -rf "${SCRIPT_DIR}/${BASE_FILE_NAME}.spk"
rm -rf "${SCRIPT_DIR}/${BASE_FILE_NAME}.spk.tmp"
rm -rf "${SCRIPT_DIR}/${BASE_FILE_NAME}.spk.signature"

TIMESERVER="http://timestamp.synology.com/timestamp.php"

unzip -q -d "${DIRNAME}" "$ZIPFILE"

for n in "../oem" "../../oem" "../../../oem"
do
    if [ -d "${SCRIPT_DIR}"/$n ]; then
        echo "Installing OEM files"
        cp -R "${SCRIPT_DIR}"/$n "${DIRNAME}/webroot/"
    fi
done

for n in "oem-app-name.txt" "oem-update-url.txt" "oem-update-key.txt" "oem-update-readme.txt" "oem-update-installid.txt"
do
    for p in "../$n" "../../$n" "../../../$n"
    do
        if [ -f "${SCRIPT_DIR}"/$p ]; then
            echo "Installing OEM override file"
            cp "${SCRIPT_DIR}"/$p "${DIRNAME}"
        fi
    done
done

# Remove items unused on the Synology platform
rm -rf ${DIRNAME}/win-tools
rm -rf ${DIRNAME}/SQLite/win64
rm -rf ${DIRNAME}/SQLite/win32
rm -rf ${DIRNAME}/MonoMac.dll
rm -rf ${DIRNAME}/alphavss
rm -rf ${DIRNAME}/OSX\ Icons
rm -rf ${DIRNAME}/OSXTrayHost
rm -f ${DIRNAME}/AlphaFS.dll
rm -f ${DIRNAME}/AlphaVSS.Common.dll
rm -rf ${DIRNAME}/licenses/alphavss
rm -rf ${DIRNAME}/licenses/MonoMac
rm -rf ${DIRNAME}/licenses/gpg

# Install extra items for Synology
cp -R ${SCRIPT_DIR}/web-extra/* ${DIRNAME}/webroot/
cp ${SCRIPT_DIR}/dsm.duplicati.conf ${DIRNAME}

DIRSIZE_KB=$(BLOCKSIZE=1024 du -s | cut -d '.' -f 1)
let "DIRSIZE=DIRSIZE_KB*1024"

tar cf ${SCRIPT_DIR}/package.tgz -C ${DIRNAME} ${DIRNAME}/*

rm -rf "${DIRNAME}"

ICON_72=$(openssl base64 -A -in "${SCRIPT_DIR}"/PACKAGE_ICON.PNG)
ICON_256=$(openssl base64 -A -in "${SCRIPT_DIR}"/PACKAGE_ICON_256.PNG)

git checkout "${SCRIPT_DIR}"/INFO
echo "version=\"${VERSION}\"" >> "${SCRIPT_DIR}/INFO"
MD5=$(md5sum "${SCRIPT_DIR}/package.tgz" | awk -F ' ' '{print $NF}')
echo "checksum=\"${MD5}\"" >> "${SCRIPT_DIR}/INFO"
echo "extractsize=\"${DIRSIZE_KB}\"" >> "${SCRIPT_DIR}/INFO"
echo "package_icon=\"${ICON_72}\"" >> "${SCRIPT_DIR}/INFO"
echo "package_icon_256=\"${ICON_256}\"" >> "${SCRIPT_DIR}/INFO"

chmod +x ${SCRIPT_DIR}/scripts/*

tar cf "${SCRIPT_DIR}/${BASE_FILE_NAME}.spk" -C ${SCRIPT_DIR} "${SCRIPT_DIR}/"INFO "${SCRIPT_DIR}/"LICENSE "${SCRIPT_DIR}/"*.PNG \
"${SCRIPT_DIR}/"package.tgz "${SCRIPT_DIR}/"scripts
# TODO: These folders are not present in git: "${SCRIPT_DIR}/"conf "${SCRIPT_DIR}/"WIZARD_UIFILES . Remove?

git checkout "${SCRIPT_DIR}/"INFO
rm -f "${SCRIPT_DIR}"/package.tgz

if [ -f "${GPG_KEYFILE}" ]; then
    if [ "z${KEYFILE_PASSWORD}" == "z" ]; then
        echo -n "Enter keyfile password: "
        read -s KEYFILE_PASSWORD
        echo
    fi

    GPGDATA=$("${MONO}" "../../BuildTools/AutoUpdateBuilder/bin/Debug/SharpAESCrypt.exe" d "${KEYFILE_PASSWORD}" "${GPG_KEYFILE}")
    if [ ! $? -eq 0 ]; then
        echo "Decrypting GPG keyfile failed"
        exit 1
    fi
    GPGID=$(echo "${GPGDATA}" | head -n 1)
    GPGKEY=$(echo "${GPGDATA}" | head -n 2 | tail -n 1)
else
    echo "No GPG keyfile found, skipping gpg signing"
fi

if [ "z${GPGID}" != "z" ]; then
    # Now codesign the spk file
    mkdir "${TMPDIRNAME}"
    tar xf "${BASE_FILE_NAME}.spk" -C "${TMPDIRNAME}"
    # Sort on macOS does not have -V / --version-sort
    # https://stackoverflow.com/questions/4493205/unix-sort-of-version-numbers
    SORT_OPTIONS="-t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n"

    cat $(find ${TMPDIRNAME} -type f | sort ${SORT_OPTIONS}) > "${BASE_FILE_NAME}.spk.tmp"

    gpg2 --ignore-time-conflict --ignore-valid-from --yes --batch --armor --detach-sign --default-key="${GPGID}" --output "${BASE_FILE_NAME}.signature" "${BASE_FILE_NAME}.spk.tmp"
    rm "${BASE_FILE_NAME}.spk.tmp"

    curl --silent --form "file=@${BASE_FILE_NAME}.signature" "${TIMESERVER}" > "${TMPDIRNAME}/syno_signature.asc"
    rm "${BASE_FILE_NAME}.signature"

    rm "${BASE_FILE_NAME}.spk"
    tar cf "${BASE_FILE_NAME}.spk" -C "${TMPDIRNAME}" $(ls -1 ${TMPDIRNAME})

    rm -rf "${TMPDIRNAME}"
fi
