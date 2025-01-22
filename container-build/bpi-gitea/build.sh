#!/bin/bash

set -e

source ${BPI_CONTAINER_BASE_DIR}/build-base.sh

cd $BPI_REPO_BASE_DIR/gitea

DOCKER_IMAGE=bpi/gitea DOCKER_TAG=local DOCKER_BUILDKIT=0 make docker
