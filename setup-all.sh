#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

echo "========================================="
echo "Complete Local Kubernetes Setup"
echo "========================================="
echo "This script will:"
echo "  1. Set up local Kubernetes cluster"
echo "  2. Build and push Kafka Monitor image"
echo "  3. Install Strimzi Operator 4.0"
echo "  4. Deploy Kafka cluster"
echo "  5. Deploy Kafka Monitor"
echo "  6. Run tests"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 1
fi

cd "${PROJECT_ROOT}"

# Step 1: Setup cluster
echo ""
echo "========================================="
echo "Step 1: Setting up Kubernetes cluster"
echo "========================================="
./local-k8s/local-k8s-setup.sh

# Step 2: Build and push
echo ""
echo "========================================="
echo "Step 2: Building and pushing image"
echo "========================================="
./build-and-push.sh

# Step 3: Install Strimzi
echo ""
echo "========================================="
echo "Step 3: Installing Strimzi Operator"
echo "========================================="
./local-k8s/deploy-kafka.sh

# Wait a bit for operator to settle
echo "Waiting for operator to settle..."
sleep 10


echo ""
echo "========================================="
echo "Step 4: Deploying Kafka Monitor"
echo "========================================="
./local-k8s/deploy-monitor.sh

echo ""
echo "========================================="
echo "Step 5: Running tests"
echo "========================================="
sleep 10
./local-k8s/test.sh

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/kafka-monitor -n kafka-monitor"
echo ""
echo "To access metrics:"
echo "  kubectl port-forward -n kafka-monitor svc/kafka-monitor 8778:8778 9090:9090"
echo ""
echo "Then open:"
echo "  http://localhost:8778/jolokia/"
echo "  http://localhost:9090/metrics"