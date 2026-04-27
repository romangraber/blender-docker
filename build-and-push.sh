#!/bin/bash
# Build and push a Blender image for a specific version.
#
# Usage:
#   ./build-and-push.sh <dockerhub-username> <full-version> <major-version>
#
# Examples:
#   ./build-and-push.sh johndoe 4.4.3 4.4
#   ./build-and-push.sh johndoe 4.5.0 4.5
#   ./build-and-push.sh johndoe 4.3.2 4.3
#
# This tags the image as both the full version and the major version,
# so you can pull either myimage:4.4.3 or myimage:4.4

set -e

USER=$1
FULL=$2
MAJOR=$3

if [ -z "$USER" ] || [ -z "$FULL" ] || [ -z "$MAJOR" ]; then
    echo "Usage: $0 <dockerhub-username> <full-version> <major-version>"
    echo "Example: $0 johndoe 4.4.3 4.4"
    exit 1
fi

IMAGE="$USER/blender-runpod"

echo "Building $IMAGE:$FULL ..."
docker build \
    --build-arg BLENDER_VERSION=$FULL \
    --build-arg BLENDER_MAJOR=$MAJOR \
    -t $IMAGE:$FULL \
    -t $IMAGE:$MAJOR \
    .

echo "Pushing $IMAGE:$FULL and $IMAGE:$MAJOR ..."
docker push $IMAGE:$FULL
docker push $IMAGE:$MAJOR

echo "Done. On RunPod, set image to: $IMAGE:$FULL  (or :$MAJOR)"
