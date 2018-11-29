SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/../shared.sh"


function build () {
    echo "travis_fold:start:build_duplicati"
    echo "+ START BUILDING BINARIES"
    eval msbuild /p:Configuration=Release "${DUPLICATI_ROOT}"/Duplicati.sln $IF_QUIET_SUPPRESS_OUTPUT
    cp -r "${DUPLICATI_ROOT}"/Duplicati/Server/webroot "${DUPLICATI_ROOT}"/Duplicati/GUI/Duplicati.GUI.TrayIcon/bin/Release/webroot
    echo "travis_fold:end:build_duplicati"
    echo "+ DONE BUILDING BINARIES"
}

parse_options "$@"
build