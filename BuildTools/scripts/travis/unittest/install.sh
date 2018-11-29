#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/../shared.sh"

apt-get update && apt-get install -y wget unzip
nuget install NUnit.Runners -Version 3.5.0 -OutputDirectory testrunner
