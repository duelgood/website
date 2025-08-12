git add .
git commit -m "Backup"
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
    -t zkeulr/duelgood:latest --push .
