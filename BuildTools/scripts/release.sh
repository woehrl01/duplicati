function upload_binaries_to_aws () {
	echo "Uploading binaries"
	aws --profile=duplicati-upload s3 cp "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip" "s3://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip"
	aws --profile=duplicati-upload s3 cp "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip.sig" "s3://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig"
	aws --profile=duplicati-upload s3 cp "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip.sig.asc" "s3://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip.sig.asc"
	aws --profile=duplicati-upload s3 cp "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.manifest" "s3://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.manifest"

	aws --profile=duplicati-upload s3 cp "s3://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.manifest" "s3://updates.duplicati.com/${RELEASE_TYPE}/latest.manifest"

	ZIP_MD5=$(md5 ${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip | awk -F ' ' '{print $NF}')
	ZIP_SHA1=$(shasum -a 1 ${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip | awk -F ' ' '{print $1}')
	ZIP_SHA256=$(shasum -a 256 ${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip | awk -F ' ' '{print $1}')

cat > "latest.json" <<EOF
{
	"version": "${RELEASE_VERSION}",
	"zip": "${RELEASE_FILE_NAME}.zip",
	"zipsig": "${RELEASE_FILE_NAME}.zip.sig",
	"zipsigasc": "${RELEASE_FILE_NAME}.zip.sig.asc",
	"manifest": "${RELEASE_FILE_NAME}.manifest",
	"urlbase": "https://updates.duplicati.com/${RELEASE_TYPE}/",
	"link": "https://updates.duplicati.com/${RELEASE_TYPE}/${RELEASE_FILE_NAME}.zip",
	"zipmd5": "${ZIP_MD5}",
	"zipsha1": "${ZIP_SHA1}",
	"zipsha256": "${ZIP_SHA256}"
}
EOF

	echo "duplicati_version_info =" > "latest.js"
	cat "latest.json" >> "latest.js"
	echo ";" >> "latest.js"

	aws --profile=duplicati-upload s3 cp "latest.json" "s3://updates.duplicati.com/${RELEASE_TYPE}/latest.json"
	aws --profile=duplicati-upload s3 cp "latest.js" "s3://updates.duplicati.com/${RELEASE_TYPE}/latest.js"
}


function post_to_forum () {
	DISCOURSE_TOKEN_FILE="${HOME}/.config/discourse-api-token"
	DISCOURSE_TOKEN=$(cat "${DISCOURSE_TOKEN_FILE}")

	if [ "x${DISCOURSE_TOKEN}" == "x" ]; then
		echo "No DISCOURSE_TOKEN found in environment, you can manually create the post on the forum"
	else

		body="# [${RELEASE_VERSION}-${RELEASE_NAME}](https://github.com/duplicati/duplicati/releases/tag/v${RELEASE_VERSION}-${RELEASE_NAME})

	${RELEASE_CHANGEINFO_NEWS}
	"

		DISCOURSE_USERNAME=$(echo "${DISCOURSE_TOKEN}" | cut -d ":" -f 1)
		DISCOURSE_APIKEY=$(echo "${DISCOURSE_TOKEN}" | cut -d ":" -f 2)

		curl -X POST "https://forum.duplicati.com/posts" \
			-F "api_key=${DISCOURSE_APIKEY}" \
			-F "api_username=${DISCOURSE_USERNAME}" \
			-F "category=Releases" \
			-F "title=Release: ${RELEASE_VERSION} (${RELEASE_TYPE}) ${RELEASE_TIMESTAMP}" \
			-F "raw=${body}"
	fi
}


function release_to_github () {
	# Using the tool from https://github.com/aktau/github-release

	GITHUB_TOKEN_FILE="${HOME}/.config/github-api-token"
	GITHUB_TOKEN=$(cat "${GITHUB_TOKEN_FILE}")
	RELEASE_MESSAGE=$(printf "Changes in this version:\n${RELEASE_CHANGEINFO_NEWS}")

	PRE_RELEASE_LABEL="--pre-release"
	if [ "${RELEASE_TYPE}" == "stable" ]; then
		PRE_RELEASE_LABEL=""
	fi

	if [ "x${GITHUB_TOKEN}" == "x" ]; then
		echo "No GITHUB_TOKEN found in environment, you can manually upload the binaries"
	else
		github-release release ${PRE_RELEASE_LABEL} \
			--tag "v${RELEASE_VERSION}-${RELEASE_NAME}"  \
			--name "v${RELEASE_VERSION}-${RELEASE_NAME}" \
			--repo "duplicati" \
			--user "duplicati" \
			--security-token "${GITHUB_TOKEN}" \
			--description "${RELEASE_MESSAGE}" \

		github-release upload \
			--tag "v${RELEASE_VERSION}-${RELEASE_NAME}"  \
			--name "${RELEASE_FILE_NAME}.zip" \
			--repo "duplicati" \
			--user "duplicati" \
			--security-token "${GITHUB_TOKEN}" \
			--file "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"
	fi
}


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


# Send the password along to avoid typing it again
export KEYFILE_PASSWORD

bash "build-installers.sh" "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"

increase_release_number
echo "+ updating git repo" && update_git_repo
echo "+ uploading to AWS" && upload_binaries_to_aws
echo "+ releasing to github" && release_to_github
echo "+ posting to forum" && post_to_forum

