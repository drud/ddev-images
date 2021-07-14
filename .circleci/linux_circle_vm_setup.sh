#!/bin/bash

set -eu -o pipefail
set -x

sudo apt-get -qq update && sudo apt-get -qq install -y docker-ce-cli binfmt-support qemu-user-static

BUILDX_BINARY_URL="https://github.com/docker/buildx/releases/download/v0.5.1/buildx-v0.5.1.linux-amd64"

curl --output docker-buildx \
  --silent --show-error --location --fail --retry 3 \
  "$BUILDX_BINARY_URL"

mkdir -p ~/.docker/cli-plugins
mv docker-buildx ~/.docker/cli-plugins
chmod a+x ~/.docker/cli-plugins/docker-buildx

if ! docker buildx inspect ddev-builder-multi --bootstrap >/dev/null; then docker buildx create --name ddev-builder-multi; fi
docker buildx use ddev-builder-multi
