#!/bin/bash
set -e

NAMESPACE="kafka-monitor"
KAFKA_NAMESPACE="kafka"

echo "========================================="
echo "Deploy Kafka Monitor"
echo "========================================="

# Check if Kafka cluster is ready
echo "Checking Kafka cluster status..."
kubectl wait --for=condition=Ready --timeout=60s kafka/my-cluster -n ${KAFKA_NAMESPACE} || {
    echo "ERROR: Kafka cluster is not ready. Please run ./deploy-kafka.sh first"
    exit 1
}

# Wait for Kafka pods to be ready
echo "Waiting for Kafka pods to be ready..."
kubectl wait --for=condition=ready pod -l strimzi.io/name=my-cluster-kafka --timeout=300s -n ${KAFKA_NAMESPACE} || {
    echo "WARNING: Kafka pods may not be fully ready, but continuing..."
}

# Create KafkaTopic for monitoring (optional, monitor can create it)
echo "Creating KafkaTopic (optional - monitor can auto-create)..."
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: kafka-monitor-topic
  namespace: ${KAFKA_NAMESPACE}
  labels:
    strimzi.io/cluster: my-cluster
spec:
  partitions: 1
  replicas: 1
  config:
    retention.ms: 3600000
EOF

# Wait a moment for topic to be created
sleep 5

# Deploy monitor
echo "Deploying Kafka Monitor..."
kubectl apply -f local-k8s/kafka-monitor-deployment.yaml

# Wait for deployment to be ready
echo ""
echo "Waiting for Kafka Monitor to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/kafka-monitor -n ${NAMESPACE}

echo ""
echo "========================================="
echo "Kafka Monitor deployed successfully!"
echo "========================================="
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}

echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/kafka-monitor -n ${NAMESPACE}"
echo ""
echo "To port-forward and access metrics:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/kafka-monitor 8778:8778 9090:9090"
echo ""
echo "Then access:"
echo "  Jolokia: http://localhost:8778/jolokia/"
echo "  Prometheus metrics: http://localhost:9090/metrics"

