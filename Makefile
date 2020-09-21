# Makefile for a standard repo with associated image

##### These variables need to be adjusted in most repositories #####

# Base docker org for tag and push
DOCKER_ORG ?= drud
SHELL=/bin/bash

DEFAULT_IMAGES = ddev-php-base ddev-php-prod
BUILD_ARCHS=linux/amd64,linux/arm64

.PHONY: prep images

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

build: images

images: $(DEFAULT_IMAGES)

$(DEFAULT_IMAGES): prep .docker-build-info.txt
	DOCKER_BUILDKIT=1 docker buildx build --progress=$(PROGRESS) $(BUILDPUSHARG) --platform linux/amd64 --label com.ddev.buildhost=${shell hostname} --target=$@  -t $(DOCKER_ORG)/$@:$(VERSION) $(DOCKER_ARGS) .

push: prep images multi_arch
	for item in $(DEFAULT_IMAGES); do \
		docker buildx build --push --platform $(BUILD_ARCHS) --label com.ddev.buildhost=${shell hostname} --target=$$item  -t $(DOCKER_ORG)/$$item:$(VERSION) $(DOCKER_ARGS) .; \
		echo "pushed $(DOCKER_ORG)/$$item"; \
	done

multi_arch: prep
	for item in $(DEFAULT_IMAGES); do \
		docker buildx build --platform $(BUILD_ARCHS) --label com.ddev.buildhost=${shell hostname} --target=$$item  -t $(DOCKER_ORG)/$$item:$(VERSION) $(DOCKER_ARGS) .; \
		echo "created multi-arch builds $(DOCKER_ORG)/$$item"; \
	done

ddev-webserver:
	docker buildx build --platform linux/amd64 -o type=docker --label com.ddev.buildhost=${shell hostname} --target=$@  -t $(DOCKER_ORG)/$@:$(VERSION) $(DOCKER_ARGS) .

test: $(DEFAULT_IMAGES)
	for item in $(DEFAULT_IMAGES); do \
		if [ -x tests/$$item/test.sh ]; then tests/$$item/test.sh $(DOCKER_ORG)/$$item:$(VERSION); fi; \
	done

version:
	@echo VERSION:$(VERSION)

.docker-build-info.txt:
	@echo "$(VERSION) $(BUILDINFO)" >.docker-build-info.txt

prep:
	# We need this to get arm64 qemu to work https://github.com/docker/buildx/issues/138#issuecomment-569240559
	docker run --rm --privileged docker/binfmt:66f9012c56a8316f9244ffd7622d7c21c1f6f28d
	if ! docker buildx inspect ddev-builder-multi --bootstrap >/dev/null; then docker buildx create --name ddev-builder-multi; fi
	docker buildx use ddev-builder-multi
