#!/bin/bash

set -e

source ${CERC_CONTAINER_BASE_DIR}/build-base.sh

cd $CERC_REPO_BASE_DIR/gitea

DOCKER_IMAGE=bpi/gitea DOCKER_TAG=local DOCKER_BUILDKIT=0 make docker
