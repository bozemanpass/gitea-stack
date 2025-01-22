#!/usr/bin/env bash
source ${BPI_CONTAINER_BASE_DIR}/build-base.sh
# Build a local version of the act-runner image
# TODO: enhance the default build code path to cope with this container (repo has an _ which needs to be converted to - in the image tag)
docker build -t bpi/act-runner:local -f ${BPI_REPO_BASE_DIR}/act_runner/Dockerfile ${build_command_args} ${BPI_REPO_BASE_DIR}/act_runner
