#!/bin/bash

echo -n | openssl s_client -connect scan.coverity.com:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' | sudo tee -a /etc/ssl/certs/ca-

nuget restore Duplicati.sln
nuget install NUnit.Runners -Version 3.5.0 -OutputDirectory testrunner
sudo pip install selenium
sudo pip install --upgrade urllib3
if [ ! -d "${TRAVIS_BUILD_DIR}"/packages/SharpCompress.0.18.2 ]; then
    ln -s "${TRAVIS_BUILD_DIR}"/packages/sharpcompress.0.18.2 "${TRAVIS_BUILD_DIR}"/packages/SharpCompress.0.18.2
fi
