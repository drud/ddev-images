#!/bin/bash

set -eu -o pipefail
set -x

# Get recent qemu to avoid constant qemu crashes on Ubuntu 20.04
# Incomprehensible discussions of the problem at
# https://bugs.launchpad.net/ubuntu/+source/qemu/+bug/1928075
sudo add-apt-repository ppa:jacob/virtualisation

sudo apt-get -qq update && sudo apt-get -qq install -y docker-ce-cli binfmt-support  qemu qemu-user qemu-user-static


# Get recent buildx
mkdir -p ~/.docker/cli-plugins && curl -sSL -o ~/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/v0.6.3/buildx-v0.6.3.linux-amd64 && chmod +x ~/.docker/cli-plugins/docker-buildx

docker buildx version

if ! docker buildx inspect ddev-builder-multi --bootstrap >/dev/null; then docker buildx create --name ddev-builder-multi --use; fi
docker buildx inspect --bootstrap