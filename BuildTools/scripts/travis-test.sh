#!/bin/bash

quit_on_error() {
    echo "Error on line $1, stopping build."
    exit 1
}

list_dir() {
    echo "listing directory $1 :"
    ls -al $1
}

trap 'quit_on_error $LINENO' ERR

CATEGORY=$1
TRAVIS_BUILD_DIR=${2:-$(dirname "$0")/../..}

if id travis &> /dev/null
then
  TESTUSER=travis
else
  TESTUSER=$(whoami)
fi

echo "Build script starting with parameters TRAVIS_BUILD_DIR=$TRAVIS_BUILD_DIR and CATEGORY=$CATEGORY"

# build duplicati

echo "travis_fold:start:build_duplicati"
echo "building binaries"
msbuild /p:Configuration=Release "${TRAVIS_BUILD_DIR}"/Duplicati.sln
cp -r "${TRAVIS_BUILD_DIR}"/Duplicati/Server/webroot "${TRAVIS_BUILD_DIR}"/Duplicati/GUI/Duplicati.GUI.TrayIcon/bin/Release/webroot
echo "travis_fold:end:build_duplicati"

# prepare dirs
if [ ! -d ~/tmp ]; then mkdir ~/tmp; fi
if [ ! -d ~/download/"${CATEGORY}" ]; then mkdir ~/download/"${CATEGORY}"; fi
rm -rf ~/duplicati_testdata/"${CATEGORY}" && mkdir -p ~/duplicati_testdata/"${CATEGORY}"

if [[ -z $ZIPFILE ]]; then
    # download and extract testdata
    echo "travis_fold:start:download_extract_testdata"

    # test if zip file exists and contains no errors, otherwise redownload
    unzip -t ~/download/"${CATEGORY}"/"${ZIPFILE}" &> /dev/null || \
    wget --progress=dot:giga "https://s3.amazonaws.com/duplicati-test-file-hosting/${ZIPFILE}" -O ~/download/"${CATEGORY}"/"${ZIPFILE}"

    list_dir ~/download/"${CATEGORY}"

    unzip -q ~/download/"${CATEGORY}"/"${ZIPFILE}" -d ~/duplicati_testdata/"${CATEGORY}"/
    list_dir ~/duplicati_testdata/"${CATEGORY}"/$(basename $ZIPFILE)

    echo "travis_fold:end:download_extract_testdata"
fi

chown -R $TESTUSER ~/duplicati_testdata/
chmod -R 755 ~/duplicati_testdata

# run unit tests
echo "travis_fold:start:unit_test"
if [[ "$CATEGORY" != "GUI"  && "$CATEGORY" != "" ]]; then
    mono "${TRAVIS_BUILD_DIR}"/testrunner/NUnit.ConsoleRunner.3.5.0/tools/nunit3-console.exe \
    "${TRAVIS_BUILD_DIR}"/Duplicati/UnitTest/bin/Release/Duplicati.UnitTest.dll --where:cat==$CATEGORY --workers=1
fi
echo "travis_fold:end:unit_test"

# start server and run gui tests
echo "travis_fold:start:gui_unit_test"
if [[ "$CATEGORY" == "GUI" ]]; then
    mono "${TRAVIS_BUILD_DIR}"/Duplicati/GUI/Duplicati.GUI.TrayIcon/bin/Release/Duplicati.Server.exe &
    python guiTests/guiTest.py
fi
echo "travis_fold:end:gui_unit_test"
