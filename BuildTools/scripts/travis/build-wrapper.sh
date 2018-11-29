#!/bin/bash

docker run -v "${TRAVIS_BUILD_DIR}:/duplicati" mono /bin/bash -c "cd /duplicati;./BuildTools/scripts/travis/install.sh ."
docker run -v "${TRAVIS_BUILD_DIR}:/duplicati" mono /bin/bash -c "cd /duplicati;./BuildTools/scripts/travis/build.sh ."