#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
DUPLICATI_ROOT="../../"

function reset_version () {
	"${MONO}" "BuildTools/UpdateVersionStamp/bin/Release/UpdateVersionStamp.exe" --version="2.0.0.7"
}

function quit_on_error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  if [[ -n "$message" ]] ; then
    echo "Error in $0 line ${parent_lineno}: ${message}; exiting with status ${code}"
  else
    echo "Error in $0 line ${parent_lineno}; exiting with status ${code}"
  fi

  eval reset_version $REDIRECT
  exit "${code}"
}

set -eE
trap 'quit_on_error $LINENO' ERR

RELEASE_CHANGELOG_FILE="${SCRIPT_DIR}/${DUPLICATI_ROOT}/changelog"
RELEASE_CHANGELOG_NEWS_FILE="${SCRIPT_DIR}/${DUPLICATI_ROOT}/changelog-news.txt" # never in repo due to .gitignore

function update_changelog () {
	if [[ ! -f "${RELEASE_CHANGELOG_NEWS_FILE}" ]]; then
		echo "No updates to add to changelog found"
		echo
		echo "To make a build without changelog news, run:"
		echo "    touch ""${RELEASE_CHANGELOG_NEWS_FILE}"" "
		return
	fi

	RELEASE_CHANGEINFO_NEWS=$(cat "${RELEASE_CHANGELOG_NEWS_FILE}" 2>/dev/null)
	if [ ! "x${RELEASE_CHANGEINFO_NEWS}" == "x" ]; then

		echo "${RELEASE_TIMESTAMP} - ${RELEASE_NAME}" > "tmp_changelog.txt"
		echo "==========" >> "tmp_changelog.txt"
		echo "${RELEASE_CHANGEINFO_NEWS}" >> "tmp_changelog.txt"
		echo >> "tmp_changelog.txt"
		cat "${RELEASE_CHANGELOG_FILE}" >> "tmp_changelog.txt"
		cp "tmp_changelog.txt" "${RELEASE_CHANGELOG_FILE}"
		rm "tmp_changelog.txt"
	fi
}

function remove_changelog_tmp () {
    rm -rf $RELEASE_CHANGELOG_NEWS_FILE
}

function reset_changelog () {
    git checkout "${RELEASE_CHANGELOG_FILE}"
}

function get_keyfile_password () {
	if [ "z${KEYFILE_PASSWORD}" == "z" ]; then
		echo -n "Enter keyfile password: "
		read -s KEYFILE_PASSWORD
		echo

        if [ "z${KEYFILE_PASSWORD}" == "z" ]; then
            echo "No password entered, quitting"
            exit 0
        fi

        export KEYFILE_PASSWORD
	fi
}

function sign_with_authenticode () {
	if [ ! -f "${AUTHENTICODE_PFXFILE}" ] || [ ! -f "${AUTHENTICODE_PASSWORD}" ]; then
		echo "Skipped authenticode signing as files are missing"
		return
	fi

	echo "Performing authenticode signing of installers"

    get_keyfile_password

	if [ "z${PFX_PASS}" == "z" ]; then
        PFX_PASS=$("${MONO}" "BuildTools/AutoUpdateBuilder/bin/Debug/SharpAESCrypt.exe" d "${KEYFILE_PASSWORD}" "${AUTHENTICODE_PASSWORD}")

        DECRYPT_STATUS=$?
        if [ "${DECRYPT_STATUS}" -ne 0 ]; then
            echo "Failed to decrypt, SharpAESCrypt gave status ${DECRYPT_STATUS}, exiting"
            exit 4
        fi

        if [ "x${PFX_PASS}" == "x" ]; then
            echo "Failed to decrypt, SharpAESCrypt gave empty password, exiting"
            exit 4
        fi
    fi

	NEST=""
	for hashalg in sha1 sha256; do
		SIGN_MSG=$(osslsigncode sign -pkcs12 "${AUTHENTICODE_PFXFILE}" -pass "${PFX_PASS}" -n "Duplicati" -i "http://www.duplicati.com" -h "${hashalg}" ${NEST} -t "http://timestamp.verisign.com/scripts/timstamp.dll" -in "$1" -out tmpfile)
		if [ "${SIGN_MSG}" != "Succeeded" ]; then echo "${SIGN_MSG}"; fi
		mv tmpfile "${ZIPFILE}"
		NEST="-nest"
	done
}

install_oem_files () {
    SOURCE_DIR=$1
    TARGET_DIR=$2
    for n in "../oem" "../../oem" "../../../oem"
    do
        if [ -d "${SOURCE_DIR}/$n" ]; then
            echo "Installing OEM files"
            cp -R "${SOURCE_DIR}/$n" "${TARGET_DIR}/webroot/"
        fi
    done

    for n in "oem-app-name.txt" "oem-update-url.txt" "oem-update-key.txt" "oem-update-readme.txt" "oem-update-installid.txt"
    do
        for p in "../$n" "../../$n" "../../../$n"
        do
            if [ -f "${SOURCE_DIR}/$p" ]; then
                echo "Installing OEM override file"
                cp "${SOURCE_DIR}/$p" "${TARGET_DIR}"
            fi
        done
    done
}

