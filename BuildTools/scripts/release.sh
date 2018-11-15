



function increase_release_number () {
    echo "${RELEASE_INC_VERSION}" > "Updates/build_version.txt"
}


RELEASE_TIMESTAMP=$(date +%Y-%m-%d)
RELEASE_INC_VERSION=$(cat Updates/build_version.txt)
RELEASE_INC_VERSION=$((RELEASE_INC_VERSION+1))
RELEASE_VERSION="2.0.4.${RELEASE_INC_VERSION}"
RELEASE_NAME="${RELEASE_VERSION}_${RELEASE_TYPE}_${RELEASE_TIMESTAMP}"
RELEASE_FILE_NAME="duplicati-${RELEASE_NAME}"


bash "build-release.sh" "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"

echo
echo "Built ${RELEASE_TYPE} version: ${RELEASE_VERSION} - ${RELEASE_NAME}"
echo "    in folder: ${UPDATE_TARGET}"
echo
echo
echo "Building installers ..."

# Send the password along to avoid typing it again
export KEYFILE_PASSWORD

bash "build-installers.sh" "${UPDATE_TARGET}/${RELEASE_FILE_NAME}.zip"