#!/usr/bin/env bash

deps() {
    if ! type -p $1 &> /dev/null; then
        echo "'$1' is required to run this script."
        exit 126
    fi
}

deps "cut"
deps "git"
deps "podman"

if ! DIR=$(git rev-parse --show-toplevel); then
    DIR=$(pwd)
fi

cd $DIR

if [[ -f "./bin/env.sh" ]]; then
    source ./bin/env.sh
fi

if [[ ! ( -f ./Dockerfile || -f ./Containerfile ) ]]; then
    echo "Directory '$DIR' has no Dockerfile or Containerfile." >&2
    exit 1
fi

REPOSITORY=${OPS_APP:-$(basename $DIR)}

if [[ -d .git ]]; then
    BRANCH=$(git branch --show-current)
    if ! $(git diff --exit-code) && $(git diff --cached --exit-code); then
        TAG="$BRANCH-dirty"
    else
        COMMIT=$(git log -1 --pretty=format:%h)
        DATE=$(\
            git show -s --format=%ci \
            | sed -re 's/[0-9]{2}([0-9]{2})-([0-9]{2})-([0-9]{2}) ([0-9]{2}):([0-9]{2}).*/\1\2\3-\4\5/g'
        )
        TAG="$BRANCH-$COMMIT-$DATE"
    fi
    IMAGE="${REPOSITORY}:${TAG}"
else
    IMAGE="$REPOSITORY:latest"
fi

if [[ ! -z "$OPS_REGISTRY" ]]; then
    IMAGE="$OPS_REGISTRY/$IMAGE"
fi

if podman build --tag $IMAGE $DIR --build-arg="APP=$REPOSITORY"; then
    echo -e "\n[ $IMAGE ]\n"
else
    echo -e "\n[ BUILD FAILED ]\n"
fi
