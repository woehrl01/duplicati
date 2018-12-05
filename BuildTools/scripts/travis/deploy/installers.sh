#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/utils.sh"

function build_installer_debian () {
	"${SCRIPT_DIR}/installers-debian.sh"
}

function build_installer_fedora () {
	RPMNAME="duplicati-${VERSION}-${BUILDTAG}.noarch.rpm"
	echo "RPMName: ${RPMNAME}"
	echo "Building Fedora RPM"

	"${DUPLICATI_ROOT}/BuildTools/Installer/fedora/docker-build-binary.sh" "${ZIPFILE}"

	mv "${DUPLICATI_ROOT}/BuildTools/Installer/fedora/${RPMNAME}" "${UPDATE_TARGET}"

	echo "Done building rpm package"
}


function build_installer_synology () {
	SPKNAME="duplicati-${BUILDTAG_RAW}.spk"
	echo "SPKName: ${SPKNAME}"
	echo "Building Synology package ..."

	"${DUPLICATI_ROOT}/BuildTools/Installer/Synology/make-binary-package.sh" "${ZIPFILE}"
	mv "${DUPLICATI_ROOT}/BuildTools/Installer/Synology/${SPKNAME}" "${UPDATE_TARGET}"
	echo "Done building synology package"
}


function build_installer_osx () {
	DMGNAME="duplicati-${BUILDTAG_RAW}.dmg"
	PKGNAME="duplicati-${BUILDTAG_RAW}.pkg"

	echo "Building OSX package locally ..."
	echo ""

	"${DUPLICATI_ROOT}/BuildTools/Installer/OSX/make-dmg.sh" "${ZIPFILE}"
	mv "${DUPLICATI_ROOT}/BuildTools/Installer/OSX/Duplicati.dmg" "../../${UPDATE_TARGET}/${DMGNAME}"
	mv "${DUPLICATI_ROOT}/BuildTools/Installer/OSX/Duplicati.pkg" "../../${UPDATE_TARGET}/${PKGNAME}"
	echo "Done building osx package"
}

function build_installer_docker () {
	echo ""
	echo ""
	echo "Building Docker images ..."

	"${DUPLICATI_ROOT}/BuildTools/Installer/Docker/build-images.sh" "${ZIPFILE}"

	echo "Done building Docker images"
}

# function build_windows_installer () {
# 	# Pre-boot virtual machine
# 	echo "Booting Win10 build instance"
# 	VBoxHeadless --startvm Duplicati-Win10-Build &

# 	echo ""
# 	echo ""
# 	echo "Building Windows instance in virtual machine"

# 	while true
# 	do
# 		ssh -o ConnectTimeout=5 IEUser@192.168.56.101 "dir"
# 		if [ $? -eq 255 ]; then
# 			echo "Windows Build machine is not responding, try restarting it"
# 			read -p "Press [Enter] key to try again"
# 			continue
# 		fi
# 		break
# 	done

# 	MSI64NAME="duplicati-${BUILDTAG_RAW}-x64.msi"
# 	MSI32NAME="duplicati-${BUILDTAG_RAW}-x86.msi"

# cat > "tmp-windows-commands.bat" <<EOF
# SET VS120COMNTOOLS=%VS140COMNTOOLS%
# cd \\Duplicati\\Installer\\Windows
# build-msi.bat "../../$1"
# EOF

# 	ssh IEUser@192.168.56.101 "\\Duplicati\\tmp-windows-commands.bat"
# 	ssh IEUser@192.168.56.101 "shutdown /s /t 0"

# 	rm "tmp-windows-commands.bat"

# 	mv "./Installer/Windows/Duplicati.msi" "${UPDATE_TARGET}/${MSI64NAME}"
# 	mv "./Installer/Windows/Duplicati-32bit.msi" "${UPDATE_TARGET}/${MSI32NAME}"

# 	VBoxManage controlvm "Duplicati-Win10-Build" poweroff
# }


function build_file_signatures() {
	if [ "z${GPGID}" != "z" ]; then
		echo "$GPGKEY" | "${GPG}" "--passphrase-fd" "0" "--batch" "--yes" "--default-key=${GPGID}" "--output" "$2.sig" "--detach-sig" "$1"
		echo "$GPGKEY" | "${GPG}" "--passphrase-fd" "0" "--batch" "--yes" "--default-key=${GPGID}" "--armor" "--output" "$2.sig.asc" "--detach-sig" "$1"
	fi

	md5 "$1" | awk -F ' ' '{print $NF}' > "$2.md5"
	shasum -a 1 "$1" | awk -F ' ' '{print $1}' > "$2.sha1"
	shasum -a 256 "$1" | awk -F ' ' '{print $1}'  > "$2.sha256"
}

function sign_with_gpg () {
	ZIP_FILE_WITH_SIGNATURES="${UPDATE_TARGET}/duplicati-${BUILDTAG_RAW}-signatures.zip"
	SIG_FOLDER="duplicati-${BUILDTAG_RAW}-signatures"
	mkdir -p "./tmp/${SIG_FOLDER}"

	for FILE in $(ls ${UPDATE_TARGET}); do
		build_file_signatures "${FILE}" "./tmp/${SIG_FOLDER}/${FILE}"
	done

	if [ "z${GPGID}" != "z" ]; then
		echo "${GPGID}" > "./tmp/${SIG_FOLDER}/sign-key.txt"
		echo "https://pgp.mit.edu/pks/lookup?op=get&search=${GPGID}" >> "./tmp/${SIG_FOLDER}/sign-key.txt"
	fi

	rm -f "${UPDATE_TARGET}/${ZIP_FILE_WITH_SIGNATURES}"

	zip -r9 "${ZIP_FILE_WITH_SIGNATURES}" "./tmp/${SIG_FOLDER}/"

	rm -rf "./tmp"
}

function set_gpg_data () {
	if [ -f "${GPG_KEYFILE}" ]; then
		if [ "z${KEYFILE_PASSWORD}" == "z" ]; then
			echo -n "Enter keyfile password: "
			read -s KEYFILE_PASSWORD
			echo
		fi

		GPGDATA=$(mono "BuildTools/AutoUpdateBuilder/bin/Debug/SharpAESCrypt.exe" d "${KEYFILE_PASSWORD}" "${GPG_KEYFILE}")
		if [ ! $? -eq 0 ]; then
			echo "Decrypting GPG keyfile failed"
			exit 1
		fi
		GPGID=$(echo "${GPGDATA}" | head -n 1)
		GPGKEY=$(echo "${GPGDATA}" | head -n 2 | tail -n 1)
	else
		echo "No GPG keyfile found, exiting"
		exit 1
	fi
}

parse_options "$@"


BUILDTYPE=$(echo "${RELEASE_FILE_NAME}" | cut -d "-" -f 2 | cut -d "_" -f 2)
BUILDTAG_RAW=$(echo "${RELEASE_FILE_NAME}" | cut -d "." -f 1-4 | cut -d "-" -f 2-4)
BUILDTAG="${BUILDTAG_RAW//-}"

echo "Building installers for: $INSTALLERS"

if [[ $INSTALLERS =~ "debian" ]]; then
	build_installer_debian
fi

if [[ $INSTALLERS =~ "fedora" ]]; then
	build_installer_fedora
fi

if [[ $INSTALLERS =~ "osx" ]]; then
	build_installer_osx
fi

if [[ $INSTALLERS =~ "synology" ]]; then
	build_installer_synology
fi

if [[ $INSTALLERS =~ "docker" ]]; then
	build_installer_docker
fi

if [[ $INSTALLERS =~ "windows" ]]; then
	build_installer_windows
fi

if [ !$UNSIGNED ]; then
	GPG=/usr/local/bin/gpg2
	set_gpg_data

	sign_with_gpg

	sign_with_authenticode "${UPDATE_TARGET}/${MSI64NAME}"
	sign_with_authenticode "${UPDATE_TARGET}/${MSI32NAME}"
fi
