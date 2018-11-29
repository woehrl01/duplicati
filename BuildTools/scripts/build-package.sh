
SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/common.sh"

function sign_binaries_with_authenticode  () {
	if [ $SIGNED != true ]
	then
		return
	fi

	get_keyfile_password

	for exec in "${UPDATE_SOURCE}/Duplicati."*.exe; do
		sign_with_authenticode "${exec}"
	done
	for exec in "${UPDATE_SOURCE}/Duplicati."*.dll; do
		sign_with_authenticode "${exec}"
	done
}

function set_gpg_autoupdate_options () {

	if [ $SIGNED != true ]
	then
		return
	fi

	get_keyfile_password
	# Newer GPG needs this to allow input from a non-terminal
	export GPG_TTY=$(tty)
	GPG_KEYFILE="${HOME}/.config/signkeys/Duplicati/updater-gpgkey.key"
	GPG=/usr/local/bin/gpg2
	UPDATER_KEYFILE="${HOME}/.config/signkeys/Duplicati/updater-release.key"
	auto_update_options="$auto_update_options --gpgkeyfile=\"${GPG_KEYFILE}\" --gpgpath=\"${GPG}\" \
	--keyfile-password=\"${KEYFILE_PASSWORD}\" --keyfile=\"${UPDATER_KEYFILE}\""
}

function generate_package () {
	UPDATE_TARGET="${DUPLICATI_ROOT}/Updates/build/${RELEASE_TYPE}_target-${RELEASE_VERSION}"
	UPDATE_ZIP_URLS="https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip;https://alt.updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip"

	if [ -e "${UPDATE_TARGET}" ]; then rm -rf "${UPDATE_TARGET}"; fi
	mkdir -p "${UPDATE_TARGET}"

	auto_update_options="--input=\"${UPDATE_SOURCE}\" --output=\"${UPDATE_TARGET}\"  \
	 --manifest=${DUPLICATI_ROOT}/Updates/${RELEASE_TYPE}.manifest --changeinfo=\"${RELEASE_CHANGEINFO}\" --displayname=\"${RELEASE_NAME}\" \
	 --remoteurls=\"${UPDATE_ZIP_URLS}\" --version=\"${RELEASE_VERSION}\""

	set_gpg_autoupdate_options

	# Remove any extra misc files before packing (like on mac)
	find "${DUPLICATI_ROOT}" -type f -name ".DS_Store" | xargs rm -rf && find  . -type f -name "Thumbs.db" | xargs rm -rf

	# if zip is not written, non-zero return code will cause script to stop
	"${MONO}" "${DUPLICATI_ROOT}/BuildTools/AutoUpdateBuilder/bin/Release/AutoUpdateBuilder.exe" $auto_update_options

	mv "${UPDATE_TARGET}/package.zip" "${UPDATE_TARGET}/latest.zip"
	mv "${UPDATE_TARGET}/autoupdate.manifest" "${UPDATE_TARGET}/latest.manifest"
	cp "${UPDATE_TARGET}/latest.zip" "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"
	cp "${UPDATE_TARGET}/latest.manifest" "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.manifest"

	if $SIGNED
	then
		mv "${UPDATE_TARGET}/package.zip.sig" "${UPDATE_TARGET}/latest.zip.sig"
		mv "${UPDATE_TARGET}/package.zip.sig.asc" "${UPDATE_TARGET}/latest.zip.sig.asc"
		cp "${UPDATE_TARGET}/latest.zip.sig" "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip.sig"
		cp "${UPDATE_TARGET}/latest.zip.sig.asc" "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip.sig.asc"
	fi
}

function prepare_update_source_folder () {
	UPDATE_SOURCE="${DUPLICATI_ROOT}/Updates/build/${RELEASE_TYPE}_source-${RELEASE_VERSION}"
	rm -rf "${UPDATE_SOURCE}"
	mkdir -p "${UPDATE_SOURCE}"

	cp -R "${DUPLICATI_ROOT}/Duplicati/GUI/Duplicati.GUI.TrayIcon/bin/Release/"* "${UPDATE_SOURCE}"
	cp -R "${DUPLICATI_ROOT}Duplicati/Server/webroot" "${UPDATE_SOURCE}"

	# We copy some files for alphavss manually as they are not picked up by xbuild
	mkdir "${UPDATE_SOURCE}/alphavss"
	for FN in "${DUPLICATI_ROOT}/Duplicati/Library/Snapshots/bin/Release/"AlphaVSS.*.dll; do
		cp "${FN}" "${UPDATE_SOURCE}/alphavss/"
	done

	# Fix for some support libraries not being picked up
	for BACKEND in "${DUPLICATI_ROOT}/Duplicati/Library/Backend/"*; do
		if [ -d "${BACKEND}/bin/Release/" ]; then
			cp "${BACKEND}/bin/Release/"*.dll "${UPDATE_SOURCE}"
		fi
	done

	# Install the assembly redirects for all Duplicati .exe files
	find "${UPDATE_SOURCE}" -maxdepth 1 -type f -name Duplicati.*.exe -exec cp ${SCRIPT_DIR}/../Installer/AssemblyRedirects.xml {}.config \;

	# Clean some unwanted build files
	for FILE in "control_dir" "Duplicati-server.sqlite" "Duplicati.debug.log" "updates"; do
		if [ -e "${UPDATE_SOURCE}/${FILE}" ]; then rm -rf "${UPDATE_SOURCE}/${FILE}"; fi
	done

	# Clean the localization spam from Azure
	for FILE in "de" "es" "fr" "it" "ja" "ko" "ru" "zh-Hans" "zh-Hant"; do
		if [ -e "${UPDATE_SOURCE}/${FILE}" ]; then rm -rf "${UPDATE_SOURCE}/${FILE}"; fi
	done

	# Clean debug files, if any
	rm -rf "${UPDATE_SOURCE}/"*.mdb "${UPDATE_SOURCE}/"*.pdb "${UPDATE_SOURCE}/"*.xml
}

function clean_and_build () {
	XBUILD=`which msbuild || /Library/Frameworks/Mono.framework/Commands/msbuild`
	NUGET=`which nuget || /Library/Frameworks/Mono.framework/Commands/nuget`

	"${XBUILD}" /property:Configuration=Release "${DUPLICATI_ROOT}/BuildTools/UpdateVersionStamp/UpdateVersionStamp.csproj"
	"${MONO}" "${DUPLICATI_ROOT}/BuildTools/UpdateVersionStamp/bin/Release/UpdateVersionStamp.exe" --version="${RELEASE_VERSION}"

	# build autoupdate
	"${NUGET}" restore "${DUPLICATI_ROOT}/BuildTools/AutoUpdateBuilder/AutoUpdateBuilder.sln"
	"${NUGET}" restore "${DUPLICATI_ROOT}/Duplicati.sln"
	"${XBUILD}" /p:Configuration=Release "${DUPLICATI_ROOT}/BuildTools/AutoUpdateBuilder/AutoUpdateBuilder.sln"

	# clean
	find "${DUPLICATI_ROOT}/Duplicati" -type d -name "Release" | xargs rm -rf
	"${XBUILD}" /p:Configuration=Release /target:Clean "${DUPLICATI_ROOT}/Duplicati.sln"

	"${XBUILD}" /p:DefineConstants=__MonoCS__ /p:DefineConstants=ENABLE_GTK /p:Configuration=Release "${DUPLICATI_ROOT}/Duplicati.sln"
}

MONO=`which mono || /Library/Frameworks/Mono.framework/Commands/mono`
SIGNED=true
REDIRECT=" > /dev/null"

while true ; do
    case "$1" in
	--debug)
		REDIRECT=""
		;;
	--unsigned)
		SIGNED=false
		;;
	--version)
		RELEASE_VERSION="$2"
		shift
		;;
    --* | -* )
        echo "unknown option $1, please use --help."
        exit 1
        ;;
    * )
		if [ "x$1" == "x" ]; then
			RELEASE_TYPE="canary"
			break
		else
			RELEASE_TYPE=$1
		fi
        ;;
    esac
    shift
done

if [[ "$RELEASE_VERSION" == "" ]]; then
	echo 'no version specified, exiting'
	exit 1
fi

RELEASE_TIMESTAMP=$(date +%Y-%m-%d)
RELEASE_NAME="${RELEASE_VERSION}_${RELEASE_TYPE}_${RELEASE_TIMESTAMP}"
RELEASE_FILE_NAME="duplicati-${RELEASE_NAME}"

echo
echo "Building package ${RELEASE_FILE_NAME}"
echo
echo "+ updating changelog" && update_changelog

echo "+ updating versions in files" && update_version_files

echo "+ compiling binaries" && eval clean_and_build $REDIRECT

echo "+ copying binaries for packaging" && prepare_update_source_folder

echo "+ signing binaries with authenticode" && sign_binaries_with_authenticode

echo "+ generating package zipfile" && eval generate_package $REDIRECT

echo "+ resetting update version stamp" && eval reset_version $REDIRECT

echo "+ resetting changelog (will be committed after deploy)" && reset_changelog

echo "+ resetting version files (will be commited after deploy)" && reset_version_files

echo
echo "= Built succesfully package delivered in: ${UPDATE_TARGET}"
echo
