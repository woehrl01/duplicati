#!/bin/bash

SCRIPT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPT_DIR}/../shared.sh"

function install_docker () {
   apt-get update
   apt-get install -y \
      apt-transport-https ca-certificates software-properties-common unzip bzip2
   #    curl \
   #    gnupg2 \


   curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
   apt-key fingerprint 0EBFCD88
   add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/debian \
      $(lsb_release -cs) \
      stable"
   apt-get update && apt-get install -y docker-ce
}

travis_mark_begin "PREPARING FOR DEPLOY"
install_docker
travis_mark_end "PREPARING FOR DEPLOY"


#apt-get install -y git
