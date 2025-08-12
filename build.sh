#!/bin/bash
IMAGE_NAME="zkeulr/duelgood"

git add .
git commit -m "Backup"
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  --no-cache \
  -t $IMAGE_NAME:latest --push .
echo "Running Docker container at localhost:80"
docker run --rm -it -p 80:80 -p 443:443 $IMAGE_NAME:latest