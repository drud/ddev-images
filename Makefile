# Makefile for a standard repo with associated image

##### These variables need to be adjusted in most repositories #####

# Base docker org for tag and push
DOCKER_ORG ?= drud
SHELL=/bin/bash

DEFAULT_IMAGES = ddev-php-base ddev-php-prod

# Optional to docker build
# DOCKER_ARGS = --build-arg MYSQL_PACKAGE_VERSION=5.7.17-1
# DOCKER_ARGS=--no-cache

# VERSION can be set by
  # Default: git tag
  # make command line: make VERSION=0.9.0
# It can also be explicitly set in the Makefile as commented out below.

# This version-strategy uses git tags to set the version string
# VERSION can be overridden on make commandline: make VERSION=0.9.1 push
VERSION := $(shell git describe --tags --always --dirty)
BUILDINFO = $(shell echo hash=$$(git rev-parse --short HEAD) Built $$(date) by $${USER} on $$(hostname) $(BUILD_IMAGE) )

# In CI environments, use the plain Docker build progress to not overload the CI logs
PROGRESS := $(if $(CI),plain,auto)

#
# This version-strategy uses a manual value to set the version string
#VERSION := 1.2.3

DOCKER_BUILDKIT=1

build: images

images: $(DEFAULT_IMAGES)

push: images
	for item in $(DEFAULT_IMAGES); do docker push $(DOCKER_ORG)/$$item:$(VERSION); echo "pushed $(DOCKER_ORG)/$$item"; done

ddev-php-prod ddev-php-base: buildinfo
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker buildx build --progress=$(PROGRESS) --platform linux/amd64,linux/arm64 --label com.ddev.buildhost=${shell hostname} --target=$@  -t $(DOCKER_ORG)/$@:$(VERSION) $(DOCKER_ARGS) .

test: images
	for item in $(DEFAULT_IMAGES); do \
		if [ -x tests/$$item/test.sh ]; then tests/$$item/test.sh $(DOCKER_ORG)/$$item:$(VERSION); fi; \
	done

version:
	@echo VERSION:$(VERSION)

buildinfo:
	@echo "$(VERSION) $(BUILDINFO)" >.docker-build-info.txt
