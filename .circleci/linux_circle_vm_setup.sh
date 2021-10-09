#!/bin/bash

set -eu -o pipefail
set -x

sudo apt-get -qq update && sudo apt-get -qq install -y docker-ce-cli binfmt-support qemu-user-static

if ! docker buildx inspect ddev-builder-multi --bootstrap >/dev/null; then docker buildx create --name ddev-builder-multi --use; fi
docker buildx inspect --bootstrap