#!/bin/bash
set -e

NAMESPACE="kafka"

echo "========================================="
echo "Deploy Kafka Cluster"
echo "========================================="


kubectl create namespace kafka

kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

# Wait for Strimzi operator to be ready
echo "Checking Strimzi operator status..."
kubectl wait --for=condition=available --timeout=60s deployment/strimzi-cluster-operator -n ${NAMESPACE} || {
    echo "ERROR: Strimzi operator is not ready."
    exit 1
}


# Apply the `Kafka` Cluster CR file
kubectl apply -f https://strimzi.io/examples/latest/kafka/kafka-single-node.yaml -n kafka 

kubectl wait kafka/my-cluster --for=condition=Ready --timeout=300s -n kafka 


echo ""
echo "========================================="
echo "Kafka cluster deployed successfully!"
echo "========================================="
kubectl get kafka -n ${NAMESPACE}
kubectl get pods -n ${NAMESPACE}

echo ""
echo "Bootstrap server: my-cluster-kafka-bootstrap.${NAMESPACE}.svc.cluster.local:9092"

