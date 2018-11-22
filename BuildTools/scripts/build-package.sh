quit_on_error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  if [[ -n "$message" ]] ; then
    echo "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}"
  else
    echo "Error on or near line ${parent_lineno}; exiting with status ${code}"
  fi

  eval reset_version $REDIRECT
  exit "${code}"
}

set -eE
trap 'quit_on_error $LINENO' ERR

function reset_version () {
	"${MONO}" "BuildTools/UpdateVersionStamp/bin/Release/UpdateVersionStamp.exe" --version="2.0.0.7"
}

function set_keyfile_password () {
	echo -n "Enter keyfile password: "
	read -s KEYFILE_PASSWORD
	echo

	if [ "z${KEYFILE_PASSWORD}" == "z" ]; then
		echo "No password entered, quitting"
		exit 0
	fi
}

function generate_package () {
	UPDATER_KEYFILE="${HOME}/.config/signkeys/Duplicati/updater-release.key"
	UPDATE_TARGET=Updates/build/${RELEASE_TYPE}_target-${RELEASE_VERSION}
	UPDATE_ZIP_URLS="https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip;https://alt.updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip"

	if [ -e "${UPDATE_TARGET}" ]; then rm -rf "${UPDATE_TARGET}"; fi
	mkdir -p "${UPDATE_TARGET}"

	# Newer GPG needs this to allow input from a non-terminal
	export GPG_TTY=$(tty)
	GPG_KEYFILE="${HOME}/.config/signkeys/Duplicati/updater-gpgkey.key"
	GPG=/usr/local/bin/gpg2

	auto_update_options="--input=\"${UPDATE_SOURCE}\" --output=\"${UPDATE_TARGET}\"  \
	 --manifest=Updates/${RELEASE_TYPE}.manifest --changeinfo=\"${RELEASE_CHANGEINFO}\" --displayname=\"${RELEASE_NAME}\" \
	 --remoteurls=\"${UPDATE_ZIP_URLS}\" --version=\"${RELEASE_VERSION}\""

	if $SIGNED
	then
		auto_update_options="$auto_update_options --gpgkeyfile=\"${GPG_KEYFILE}\" --gpgpath=\"${GPG}\" \
		--keyfile-password=\"${KEYFILE_PASSWORD}\" --keyfile=\"${UPDATER_KEYFILE}\""
	fi

	# if zip is not written, non-zero return code will cause script to stop
	"${MONO}" "BuildTools/AutoUpdateBuilder/bin/Release/AutoUpdateBuilder.exe" $auto_update_options

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
	UPDATE_SOURCE=Updates/build/${RELEASE_TYPE}_source-${RELEASE_VERSION}
	rm -rf "${UPDATE_SOURCE}"
	mkdir -p "${UPDATE_SOURCE}"

	cp -R Duplicati/GUI/Duplicati.GUI.TrayIcon/bin/Release/* "${UPDATE_SOURCE}"
	cp -R Duplicati/Server/webroot "${UPDATE_SOURCE}"

	# We copy some files for alphavss manually as they are not picked up by xbuild
	mkdir "${UPDATE_SOURCE}/alphavss"
	for FN in Duplicati/Library/Snapshots/bin/Release/AlphaVSS.*.dll; do
		cp "${FN}" "${UPDATE_SOURCE}/alphavss/"
	done

	# Fix for some support libraries not being picked up
	for BACKEND in Duplicati/Library/Backend/*; do
		if [ -d "${BACKEND}/bin/Release/" ]; then
			cp "${BACKEND}/bin/Release/"*.dll "${UPDATE_SOURCE}"
		fi
	done

	# Install the assembly redirects for all Duplicati .exe files
	find "${UPDATE_SOURCE}" -maxdepth 1 -type f -name Duplicati.*.exe -exec cp Installer/AssemblyRedirects.xml {}.config \;

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

	"${XBUILD}" /property:Configuration=Release "BuildTools/UpdateVersionStamp/UpdateVersionStamp.csproj"
	"${MONO}" "BuildTools/UpdateVersionStamp/bin/Release/UpdateVersionStamp.exe" --version="${RELEASE_VERSION}"

	# build autoupdate
	"${NUGET}" restore "BuildTools/AutoUpdateBuilder/AutoUpdateBuilder.sln"
	"${NUGET}" restore "Duplicati.sln"
	"${XBUILD}" /p:Configuration=Release "BuildTools/AutoUpdateBuilder/AutoUpdateBuilder.sln"

	# clean
	find "Duplicati" -type d -name "Release" | xargs rm -rf
	"${XBUILD}" /p:Configuration=Release /target:Clean "Duplicati.sln"

	"${XBUILD}" /p:DefineConstants=__MonoCS__ /p:DefineConstants=ENABLE_GTK /p:Configuration=Release "Duplicati.sln"
}

function update_text_files_with_new_version() {
	UPDATE_MANIFEST_URLS="https://updates.duplicati.com/${RELEASE_TYPE}/latest.manifest;https://alt.updates.duplicati.com/${RELEASE_TYPE}/latest.manifest"


	if [[ ! -f "${RELEASE_CHANGELOG_NEWS_FILE}" ]]; then
		echo "No updates to add to changelog found"
		echo
		echo "To make a build without changelog news, run:"
		echo "    touch ""${RELEASE_CHANGELOG_NEWS_FILE}"" "
		exit 0
	fi

	RELEASE_CHANGELOG_NEWS_FILE="changelog-news.txt" # never in repo due to .gitignore
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
	rm "${RELEASE_CHANGELOG_NEWS_FILE}"

	echo "${RELEASE_NAME}" > "Duplicati/License/VersionTag.txt"
	echo "${RELEASE_TYPE}" > "Duplicati/Library/AutoUpdater/AutoUpdateBuildChannel.txt"
	echo "${UPDATE_MANIFEST_URLS}" > "Duplicati/Library/AutoUpdater/AutoUpdateURL.txt"
	cp "Updates/release_key.txt"  "Duplicati/Library/AutoUpdater/AutoUpdateSignKey.txt"

	# TODO: in case of auto releasing, put some git log in changelog.
	RELEASE_CHANGEINFO=$(cat ${RELEASE_CHANGELOG_FILE})
	if [ "x${RELEASE_CHANGEINFO}" == "x" ]; then
		echo "No information in changelog file"
		exit 0
	fi
}

MONO=`which mono || /Library/Frameworks/Mono.framework/Commands/mono`
LOCAL=false
AUTO_RELEASE=false
SIGNED=true
REDIRECT=" > /dev/null"

while true ; do
    case "$1" in
    --help)
        show_help
        exit 0
        ;;
	--debug)
		REDIRECT=""
		;;
	--local)
		LOCAL=true
		;;
	--auto)
		AUTO_RELEASE=true
		;;
	--unsigned)
		SIGNED=false
		;;
    --* | -* )
        echo "unknown option $1, please use --help."
        exit 1
        ;;
    * )
		if [ "x$1" == "x" ]; then
			RELEASE_TYPE="canary"
			echo "No release type specified, using ${RELEASE_TYPE}"
			break
		else
			RELEASE_TYPE=$1
		fi
        ;;
    esac
    shift
done

BUILD_DIR=$(dirname "$0")/../..
cd $BUILD_DIR

. ${SCRIPT_DIR}/common.sh


RELEASE_TIMESTAMP=$(date +%Y-%m-%d)
RELEASE_INC_VERSION=$(cat Updates/build_version.txt)
RELEASE_INC_VERSION=$((RELEASE_INC_VERSION+1))
RELEASE_VERSION="2.0.4.${RELEASE_INC_VERSION}"
RELEASE_NAME="${RELEASE_VERSION}_${RELEASE_TYPE}_${RELEASE_TIMESTAMP}"
RELEASE_CHANGELOG_FILE="changelog.txt"
RELEASE_FILE_NAME="duplicati-${RELEASE_NAME}"

$LOCAL || update_text_files_with_new_version

echo "+ compiling binaries" && eval clean_and_build $REDIRECT

echo "+ copying binaries for packaging" && prepare_update_source_folder

# Remove all .DS_Store and Thumbs.db files
find  . -type f -name ".DS_Store" | xargs rm -rf && find  . -type f -name "Thumbs.db" | xargs rm -rf

$SIGNED && echo "+ getting key to sign" && set_keyfile_password

if $SIGNED
then
	echo "+ signing with authenticode"
	for exec in "${UPDATE_SOURCE}/Duplicati."*.exe; do
		sign_with_authenticode "${exec}"
	done
	for exec in "${UPDATE_SOURCE}/Duplicati."*.dll; do
		sign_with_authenticode "${exec}"
	done
fi

echo "generating package zipfile" && eval generate_package $REDIRECT

eval reset_version $REDIRECT

echo
echo "Built ${RELEASE_TYPE} version: ${RELEASE_VERSION} - ${RELEASE_NAME}"
echo "    in folder: ${UPDATE_TARGET}"
echo

if $LOCAL
then
  	exit 0
fi

return
