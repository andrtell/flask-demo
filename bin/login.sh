#!/usr/bin/env bash

if ! DIR=$(git rev-parse --show-toplevel); then
    DIR=$(pwd)
fi

cd $DIR

if [[ -f "./bin/env.sh" ]]; then
    source ./bin/env.sh
fi

if [[ -z $OPS_REGISTRY ]]; then
    echo "OPS_REGISTRY is empty or not set." >&2
    exit 1
fi

if [[ -z $OPS_REGISTRY_USER ]]; then
    echo "OPS_REGISTRY_USER is empty or not set." >&2
    exit 1
fi

podman login $OPS_REGISTRY --secret=$OPS_REGISTRY_USER
