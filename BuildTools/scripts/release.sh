

function update_git_repo () {
	git checkout "Duplicati/License/VersionTag.txt"
	git checkout "Duplicati/Library/AutoUpdater/AutoUpdateURL.txt"
	git checkout "Duplicati/Library/AutoUpdater/AutoUpdateBuildChannel.txt"
	git add "Updates/build_version.txt"
	git add "${RELEASE_CHANGELOG_FILE}"
	git commit -m "Version bump to v${RELEASE_VERSION}-${RELEASE_NAME}" -m "You can download this build from: " -m "Binaries: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip" -m "Signature file: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig" -m "ASCII signature file: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig.asc" -m "MD5: ${ZIP_MD5}" -m "SHA1: ${ZIP_SHA1}" -m "SHA256: ${ZIP_SHA256}"
	git tag "v${RELEASE_VERSION}-${RELEASE_NAME}"                       -m "You can download this build from: " -m "Binaries: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip" -m "Signature file: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig" -m "ASCII signature file: https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig.asc" -m "MD5: ${ZIP_MD5}" -m "SHA1: ${ZIP_SHA1}" -m "SHA256: ${ZIP_SHA256}"
	git push --tags
}



function increase_release_number () {
    echo "${RELEASE_INC_VERSION}" > "Updates/build_version.txt"
}



$LOCAL || git stash save "auto-build-${RELEASE_TIMESTAMP}"

echo
echo "Building package ..."

. ./build-package.sh

echo $RELEASE_FILE_NAME
exit

echo
echo "Building installers ..."
mkdir -p "${UPDATE_TARGET}/Installers"
bash "build-installers.sh" --target-dir "${UPDATE_TARGET}/Installers" "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"

# Send the password along to avoid typing it again
export KEYFILE_PASSWORD


increase_release_number
echo "+ updating git repo" && update_git_repo
echo "+ uploading to AWS" && upload_binaries_to_aws
echo "+ releasing to github" && release_to_github
echo "+ posting to forum" && post_to_forum

