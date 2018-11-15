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

TRAVIS_BUILD_DIR=${1:-$(dirname "$0")/../..}
CATEGORY=$2
ZIPFILE=$3
export UNITTEST_BASEFOLDER=~/duplicati_testdata/"${CATEGORY}"

if id travis &> /dev/null
then
  TESTUSER=travis
else
  TESTUSER=$(whoami)
fi

# prepare dirs
if [ ! -d ~/tmp ]; then mkdir ~/tmp; fi
if [ ! -d ~/download/"${CATEGORY}" ]; then mkdir ~/download/"${CATEGORY}"; fi
rm -rf ${UNITTEST_BASEFOLDER} && mkdir -p ${UNITTEST_BASEFOLDER}

if [[ -z $ZIPFILE ]]; then
    # download and extract testdata
    echo "travis_fold:start:download_extract_testdata"

    # test if zip file exists and contains no errors, otherwise redownload
    unzip -t ~/download/"${CATEGORY}"/"${ZIPFILE}" &> /dev/null || \
    wget --progress=dot:giga "https://s3.amazonaws.com/duplicati-test-file-hosting/${ZIPFILE}" -O ~/download/"${CATEGORY}"/"${ZIPFILE}"

    list_dir ~/download/"${CATEGORY}"

    unzip -q ~/download/"${CATEGORY}"/"${ZIPFILE}" -d ${UNITTEST_BASEFOLDER}
    list_dir ~/duplicati_testdata/"${CATEGORY}"/$(basename $ZIPFILE)

    echo "travis_fold:end:download_extract_testdata"
fi

chown -R $TESTUSER ${UNITTEST_BASEFOLDER}
chmod -R 755 ${UNITTEST_BASEFOLDER}

# run unit tests
echo "travis_fold:start:unit_test"
if [[ "$CATEGORY" != "GUI" ]]; then
    mono "${TRAVIS_BUILD_DIR}"/testrunner/NUnit.ConsoleRunner.3.5.0/tools/nunit3-console.exe \
    "${TRAVIS_BUILD_DIR}"/Duplicati/UnitTest/bin/Release/Duplicati.UnitTest.dll --where:cat==$CATEGORY --workers=1
else
    mono "${TRAVIS_BUILD_DIR}"/Duplicati/GUI/Duplicati.GUI.TrayIcon/bin/Release/Duplicati.Server.exe &
    python guiTests/guiTest.py
fi
echo "travis_fold:end:unit_test"