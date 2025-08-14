#!/bin/bash

IMAGE_NAME="zkeulr/duelgood"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

git add .
git commit -m "Update $TIMESTAMP" 

docker-compose down 2>/dev/null || true

docker buildx create --use --name multiarch-builder 2>/dev/null || true
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag $IMAGE_NAME:latest \
    --tag $IMAGE_NAME:$TIMESTAMP \
    --push \

docker pull $IMAGE_NAME:latest
docker-compose up -d