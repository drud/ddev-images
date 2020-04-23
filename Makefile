# Makefile for a standard repo with associated container

##### These variables need to be adjusted in most repositories #####

# Base docker repo repo for a push
DOCKER_REPO ?= drud/ddev-php-web
SHELL=/bin/bash

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
#
# This version-strategy uses a manual value to set the version string
#VERSION := 1.2.3

DOCKER_BUILDKIT=1

build: container

container: container-name
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker build --label com.ddev.buildhost=${HOSTNAME} --label com.ddev.buildcommit=$(shell git describe --tags --always)  -t $(DOCKER_REPO):$(VERSION) $(DOCKER_ARGS) .

container-name:
	@echo "container: $(DOCKER_REPO):$(VERSION)"

push: push-name
	docker push $(DOCKER_REPO):$(VERSION)

push-name:
	@echo "pushed: $(DOCKER_REPO):$(VERSION)"

ddev-nginx ddev-php ddev-webserver: 
	DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) docker build --label com.ddev.buildhost=${HOSTNAME} --target=$< --label com.ddev.buildcommit=$(shell git describe --tags --always)  -t $@:$(VERSION) $(DOCKER_ARGS) .
