#!/bin/bash

IMAGE_NAME="zkeulr/duelgood"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "🚀 Starting build process..."

# Check if git repo has changes
if [ -n "$(git status --porcelain)" ]; then
    echo "📝 Committing changes to git..."
    git add .
    git commit -m "Update $(date +'%Y-%m-%d %H:%M:%S')"
    
    # Push to git (optional - remove if you don't want auto-push to git)
    echo "📤 Pushing to git repository..."
    git push origin main 2>/dev/null || git push origin master 2>/dev/null || echo "⚠️  Could not push to git (continuing anyway)"
else
    echo "ℹ️  No git changes to commit"
fi

# Stop and remove existing container
echo "🛑 Stopping existing container..."
docker-compose down 2>/dev/null || true

# Build and push to Docker Hub
echo "🔨 Building and pushing Docker image..."
docker buildx create --use --name multiarch-builder 2>/dev/null || true
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag $IMAGE_NAME:latest \
    --tag $IMAGE_NAME:$TIMESTAMP \
    --push \
    .

if [ $? -eq 0 ]; then
    echo "✅ Successfully built and pushed $IMAGE_NAME:latest"
    echo "✅ Also tagged as $IMAGE_NAME:$TIMESTAMP"
else
    echo "❌ Build failed!"
    exit 1
fi

# Pull the latest image locally and run with docker-compose
echo "📥 Pulling latest image and starting container..."
docker pull $IMAGE_NAME:latest

echo "🚀 Starting services with docker-compose..."
docker-compose up -d

# Show container status
echo ""
echo "📊 Container Status:"
docker-compose ps

echo ""
echo "🌐 Your site should be available at:"
echo "   HTTP:  http://localhost"
echo "   HTTPS: https://localhost (self-signed cert)"
echo ""
echo "📋 Useful commands:"
echo "   View logs:     docker-compose logs -f"
echo "   Stop service:  docker-compose down"
echo "   Restart:       docker-compose restart"
echo ""
echo "✨ Build complete!"