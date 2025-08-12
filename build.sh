#!/bin/bash

IMAGE_NAME="zkeulr/duelgood"

git add .
git commit -m "Backup"
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
    -t $IMAGE_NAME:latest --push .

echo "Running Docker container at localhost:443"
docker run --rm -it -p 80:80 -p 443:443 $IMAGE_NAME
