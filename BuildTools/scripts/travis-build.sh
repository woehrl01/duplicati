# build duplicati

TRAVIS_BUILD_DIR=${2:-$(dirname "$0")/../..}

echo "travis_fold:start:build_duplicati"
echo "building binaries"
msbuild /p:Configuration=Release "${TRAVIS_BUILD_DIR}"/Duplicati.sln
cp -r "${TRAVIS_BUILD_DIR}"/Duplicati/Server/webroot "${TRAVIS_BUILD_DIR}"/Duplicati/GUI/Duplicati.GUI.TrayIcon/bin/Release/webroot
echo "travis_fold:end:build_duplicati"
