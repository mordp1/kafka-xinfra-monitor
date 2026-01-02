#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

REGISTRY="localhost:5000"
IMAGE_NAME="kafka-monitor"
IMAGE_TAG="latest"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "========================================="
echo "Build and Push Kafka Monitor Image"
echo "========================================="

# Check if cluster exists
if ! kind get clusters | grep -q "^kafka-test$"; then
    echo "ERROR: Kubernetes cluster 'kafka-test' does not exist."
    echo "Please run ./local-k8s-setup.sh first"
    exit 1
fi

# Build the application first
echo "Building application with Gradle..."
# Skip tests and checkstyle for faster local builds
./gradlew clean build -x test -x checkstyleMain -x checkstyleTest

# Check if build was successful
if [ ! -d "build/libs" ] || [ -z "$(ls -A build/libs/*.jar 2>/dev/null)" ]; then
    echo "ERROR: Build failed or no JAR files found in build/libs/"
    exit 1
fi

echo ""
echo "Building Docker image..."
# Build from project root, using kubernetes/Dockerfile
docker build -f kubernetes/Dockerfile -t ${FULL_IMAGE} .

echo ""
echo "Loading image into kind cluster..."
kind load docker-image ${FULL_IMAGE} --name kafka-test

echo ""
echo "Also pushing to local registry for reference..."
docker push ${FULL_IMAGE} || echo "Note: Push to registry may fail if registry is not accessible, but image is loaded in kind"

echo ""
echo "========================================="
echo "Build and push complete!"
echo "========================================="
echo "Image: ${FULL_IMAGE}"
echo ""
echo "Image is loaded in kind cluster and ready to use"

