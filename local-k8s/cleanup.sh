#!/bin/bash
set -e

CLUSTER_NAME="kafka-test"
REGISTRY_NAME="kind-registry"

echo "========================================="
echo "Cleanup Local Kubernetes Setup"
echo "========================================="

read -p "This will delete the Kubernetes cluster and registry. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 1
fi

# Delete cluster
echo "Deleting Kubernetes cluster..."
kind delete cluster --name ${CLUSTER_NAME}

# Optionally delete registry
read -p "Delete local registry container? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker stop ${REGISTRY_NAME} 2>/dev/null || true
    docker rm ${REGISTRY_NAME} 2>/dev/null || true
    echo "Registry container deleted"
fi

echo ""
echo "========================================="
echo "Cleanup complete!"
echo "========================================="