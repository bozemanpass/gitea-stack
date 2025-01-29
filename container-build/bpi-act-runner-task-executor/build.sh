#!/usr/bin/env bash
# Build a local version of the task executor for act-runner
source ${BPI_CONTAINER_BASE_DIR}/build-base.sh
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd ${BPI_REPO_BASE_DIR}/gitea-stack/act-runner
docker build -t bpi/act-runner-task-executor:local -f Dockerfile.task-executor ${build_command_args} .
