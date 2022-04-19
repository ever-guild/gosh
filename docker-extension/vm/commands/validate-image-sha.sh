#!/bin/bash
set -e

# 

# params: repo commit_hash
# output: gosh_hash

GOSH_REMOTE_URL=$1
COMMIT_HASH=$2

NETWORKS="${NETWORKS:-https://gra01.net.everos.dev,https://rbx01.net.everos.dev,https://eri01.net.everos.dev}"

{
    LAST_PWD=$(pwd)
    mkdir -p /workdir/"$REPOSITORY_NAME"
    cd /workdir/"$REPOSITORY_NAME"

    git clone "$GOSH_REMOTE_URL" "$REPOSITORY_NAME"

    cd "$REPOSITORY_NAME"
    git fetch -a
    git checkout "$COMMIT_HASH"

    IDDFILE=../"$REPOSITORY_NAME".iidfile

    docker buildx build \
        -f goshfile.yaml \
        --load \
        --iidfile "$IDDFILE" \
        --no-cache \
        .

    TARGET_IMAGE=$(< "$IDDFILE")

    if [[ -z "$TARGET_IMAGE" ]]; then
        echo "Error: Image was not built"
        exit 1
    fi

    GOSH_SHA=$(./gosh-image-sha "$TARGET_IMAGE")
    docker rmi "$TARGET_IMAGE" || true

    cd "$LAST_PWD"
} >&2

echo "$GOSH_SHA"