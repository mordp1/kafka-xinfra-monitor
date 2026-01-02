#!/bin/bash
set -e

CLUSTER_NAME="kafka-test"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5000"

# Check if port 5000 is available, use 5001 if not
ORIGINAL_PORT="${REGISTRY_PORT}"
if lsof -i :${REGISTRY_PORT} &>/dev/null; then
    echo "WARNING: Port ${REGISTRY_PORT} is already in use (likely AirPlay Receiver on macOS)"
    REGISTRY_PORT="5001"
    echo "Using alternative port: ${REGISTRY_PORT}"
    # Remove existing container if it was using the old port
    if docker inspect "${REGISTRY_NAME}" &>/dev/null; then
        echo "Removing existing container to recreate with new port..."
        docker rm -f "${REGISTRY_NAME}" 2>/dev/null || true
    fi
fi

echo "========================================="
echo "Local Kubernetes Setup for Kafka Testing"
echo "========================================="

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo "ERROR: kind is not installed. Please install it first:"
    echo "  brew install kind  # macOS"
    echo "  or visit: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed. Please install it first."
    exit 1
fi

# Delete existing cluster if it exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "Deleting existing cluster: ${CLUSTER_NAME}"
    kind delete cluster --name ${CLUSTER_NAME}
fi

# Create or start registry container
if docker inspect "${REGISTRY_NAME}" &>/dev/null; then
    # Container exists, check if running
    if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}")" = "true" ]; then
        echo "Registry container already running"
        # Verify it's using the correct port
        CURRENT_PORT=$(docker port "${REGISTRY_NAME}" 5000 2>/dev/null | cut -d: -f1 || echo "")
        if [ "${CURRENT_PORT}" != "${REGISTRY_PORT}" ] && [ -n "${CURRENT_PORT}" ]; then
            echo "WARNING: Registry is using port ${CURRENT_PORT} instead of ${REGISTRY_PORT}"
            REGISTRY_PORT="${CURRENT_PORT}"
        fi
    else
        echo "Starting existing registry container..."
        # Remove if in bad state
        if docker start "${REGISTRY_NAME}" 2>/dev/null; then
            echo "Registry container started"
        else
            echo "Removing old container in bad state and creating a new one..."
            docker rm -f "${REGISTRY_NAME}" 2>/dev/null || true
            docker run -d --restart=always -p "${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" registry:2
        fi
    fi
else
    echo "Creating local registry container on port ${REGISTRY_PORT}..."
    docker run -d --restart=always -p "${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" registry:2
fi

# Create cluster config with registry
cat <<EOF | kind create cluster --name ${CLUSTER_NAME} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
  - role: worker
EOF

# Connect registry to cluster network
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks}}' "${REGISTRY_NAME}" | grep -q "${CLUSTER_NAME}" || echo "not connected")" == "not connected" ]; then
    echo "Connecting registry to cluster network..."
    docker network connect "kind" "${REGISTRY_NAME}" || true
fi

# Configure containerd to use local registry
echo "Configuring containerd to use local registry..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-system
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo ""
echo "========================================="
echo "Cluster setup complete!"
echo "========================================="
echo "Cluster name: ${CLUSTER_NAME}"
echo "Registry: localhost:${REGISTRY_PORT}"
echo ""
echo "To use the registry:"
echo "  docker tag <image> localhost:${REGISTRY_PORT}/<image>"
echo "  docker push localhost:${REGISTRY_PORT}/<image>"
echo ""
echo "Next steps:"
echo "  1. Run: ./build-and-push.sh"
echo "  2. Run: ./deploy-kafka.sh
echo "  3. Run: ./deploy-monitor.sh