#!/usr/bin/env bash
if [[ -n "$STACK_SCRIPT_DEBUG" ]]; then
    set -x
fi

mkdir -p ${STACK_DEPLOYMENT_DIR}/data/gitea-data/ssh