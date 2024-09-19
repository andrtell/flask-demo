#!/usr/bin/env bash

deps() {
    if ! type -p $1 &> /dev/null; then
        echo "'$1' is required to run this script."
        exit 126
    fi
}

deps "podman"
deps "fzf"

if ! DIR=$(git rev-parse --show-toplevel); then
    DIR=$(pwd)
fi

cd $DIR

if [[ ! -f "./bin/env.sh" ]]; then
    echo "env.sh not found in $(pwd)."
    exit 1
fi

source ./bin/env.sh

REPOSITORY=${OPS_APP:-$(basename $DIR)}

if [[ -z $OPS_REGISTRY ]]; then
    echo "OPS_REGISTRY is empty or not set." >&2
    exit 1
fi

if [[ $# -lt 1 && -z $OPS_DOMAIN ]]; then
    echo "OPS_DOMAIN is empty or not set and no argument given."
    exit 1
fi

DOMAIN=${1:-$OPS_DOMAIN}

CONTAINER=${DOMAIN//./_}

IMAGE=$( \
    podman images --filter="reference=$OPS_REGISTRY/$REPOSITORY:*" \
    | tail -n +2 \
    | fzf --height='~100%' \
    | awk -F ' ' '{print $1 ":" $2}' \
)

echo
if ! podman push $IMAGE; then
    echo -e "\n[ PUSH FAILED ]\n"
    exit 1
fi

if [[ ! -z "${OPS_PODMAN_CONNECTION}" ]]; then
    CONNECTION="-c $OPS_PODMAN_CONNECTION"
fi

if ! podman -r $CONNECTION pull $IMAGE; then
    echo -e "\n[ PULL FAILED ]\n"
    exit 1
fi

SECRET_KEY=$(python -c 'import secrets; print(secrets.token_hex())')

podman -r $CONNECTION run \
    -d \
    --name=$CONTAINER \
    --restart=always \
    --replace \
    --network='traefik' \
    --env="SECRET_KEY=$SECRET_KEY" \
    --label='traefik.enable=true' \
    --label="traefik.http.routers.$CONTAINER.entrypoints=websecure" \
    --label="traefik.http.routers.$CONTAINER.rule=Host(\`$DOMAIN\`)" \
    --label="traefik.http.routers.$CONTAINER.tls=true" \
    --label="traefik.http.routers.$CONTAINER.tls.certresolver=letsencrypt" \
    "$IMAGE"

echo -e "\n[ LOG ]\n"

podman -r $CONNECTION logs -f $CONTAINER
