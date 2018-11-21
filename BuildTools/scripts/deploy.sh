


function upload_installers_to_aws() {
	process_installer() {
		if [ "$2" != "zip" ]; then
			aws --profile=duplicati-upload s3 cp "${UPDATE_TARGET}/$1" "s3://updates.duplicati.com/${BUILDTYPE}/$1"
		fi

		local MD5=$(md5 ${UPDATE_TARGET}/$1 | awk -F ' ' '{print $NF}')
		local SHA1=$(shasum -a 1 ${UPDATE_TARGET}/$1 | awk -F ' ' '{print $1}')
		local SHA256=$(shasum -a 256 ${UPDATE_TARGET}/$1 | awk -F ' ' '{print $1}')

cat >> "./tmp/latest-installers.json" <<EOF
	"$2": {
		"name": "$1",
		"url": "https://updates.duplicati.com/${BUILDTYPE}/$1",
		"md5": "${MD5}",
		"sha1": "${SHA1}",
		"sha256": "${SHA256}"
	},
EOF
	}

	rm -rf "./tmp"

	mkdir "./tmp"

	echo "{" > "./tmp/latest-installers.json"

	process_installer "${ZIPFILE}" "zip"
	process_installer "${SPKNAME}" "spk"
	process_installer "${RPMNAME}" "rpm"
	process_installer "${DEBNAME}" "deb"
	process_installer "${DMGNAME}" "dmg"
	process_installer "${PKGNAME}" "pkg"
	process_installer "${MSI32NAME}" "msi86"
	process_installer "${MSI64NAME}" "msi64"

cat >> "./tmp/latest-installers.json" <<EOF
	"version": "${VERSION}"
}
EOF

	echo "duplicati_installers =" > "./tmp/latest-installers.js"
	cat "./tmp/latest-installers.json" >> "./tmp/latest-installers.js"
	echo ";" >> "./tmp/latest-installers.js"

	aws --profile=duplicati-upload s3 cp "./tmp/latest-installers.json" "s3://updates.duplicati.com/${BUILDTYPE}/latest-installers.json"
	aws --profile=duplicati-upload s3 cp "./tmp/latest-installers.js" "s3://updates.duplicati.com/${BUILDTYPE}/latest-installers.js"

	rm -rf "./tmp"
}

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



function deploy_docker () {
	ARCHITECTURES="amd64 arm32v7"

	for arch in $ARCHITECTURES; do
    	tags="linux-${arch}-${VERSION} linux-${arch}-${CHANNEL}"
		for tag in $tags; do
	        docker push ${REPOSITORY}:${tag}
		done
	done
}


GITHUB_TOKEN_FILE="${HOME}/.config/github-api-token"
