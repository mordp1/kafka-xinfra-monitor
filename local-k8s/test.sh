#!/bin/bash
set -e

NAMESPACE="kafka-monitor"
KAFKA_NAMESPACE="kafka"

echo "========================================="
echo "Test Kafka Monitor Deployment"
echo "========================================="

# Check if monitor pod is running
echo "1. Checking Kafka Monitor pod status..."
if kubectl get pods -n ${NAMESPACE} -l app=kafka-monitor | grep -q Running; then
    echo "✓ Kafka Monitor pod is running"
    kubectl get pods -n ${NAMESPACE} -l app=kafka-monitor
else
    echo "✗ Kafka Monitor pod is not running"
    kubectl get pods -n ${NAMESPACE} -l app=kafka-monitor
    exit 1
fi

# Check logs for errors
echo ""
echo "2. Checking recent logs for errors..."
if kubectl logs -n ${NAMESPACE} -l app=kafka-monitor --tail=20 | grep -i "error\|exception\|fatal" | head -5; then
    echo "⚠ Found some errors in logs (may be normal during startup)"
else
    echo "✓ No critical errors found in recent logs"
fi

# Test Jolokia endpoint
echo ""
echo "3. Testing Jolokia endpoint..."
POD_NAME=$(kubectl get pods -n ${NAMESPACE} -l app=kafka-monitor -o jsonpath='{.items[0].metadata.name}')
if kubectl exec -n ${NAMESPACE} ${POD_NAME} -- wget -q -O- http://localhost:8778/jolokia/version 2>/dev/null | grep -q "agent"; then
    echo "✓ Jolokia endpoint is responding"
else
    echo "✗ Jolokia endpoint is not responding"
    echo "  Trying direct curl..."
    kubectl exec -n ${NAMESPACE} ${POD_NAME} -- curl -s http://localhost:8778/jolokia/version || echo "  Failed"
fi

# Test Prometheus metrics endpoint
echo ""
echo "4. Testing Prometheus metrics endpoint..."
if kubectl exec -n ${NAMESPACE} ${POD_NAME} -- wget -q -O- http://localhost:9090/metrics 2>/dev/null | grep -q "kafka"; then
    echo "✓ Prometheus metrics endpoint is responding"
    METRIC_COUNT=$(kubectl exec -n ${NAMESPACE} ${POD_NAME} -- wget -q -O- http://localhost:9090/metrics 2>/dev/null | grep -c "^kafka_monitor" || echo "0")
    echo "  Found ${METRIC_COUNT} kafka_monitor metrics"
else
    echo "✗ Prometheus metrics endpoint is not responding"
fi

# Check Kafka topic
echo ""
echo "5. Checking Kafka topic..."
if kubectl get kafkatopic kafka-monitor-topic -n ${KAFKA_NAMESPACE} &>/dev/null; then
    echo "✓ Kafka topic 'kafka-monitor-topic' exists"
    kubectl get kafkatopic kafka-monitor-topic -n ${KAFKA_NAMESPACE}
else
    echo "⚠ Kafka topic may be auto-created by the monitor"
fi

# Get monitor metrics via Jolokia
echo ""
echo "6. Getting monitor metrics..."
kubectl exec -n ${NAMESPACE} ${POD_NAME} -- curl -s http://localhost:8778/jolokia/read/kmf:type=kafka-monitor:offline-runnable-count 2>/dev/null | head -c 200
echo ""

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "To view full logs:"
echo "  kubectl logs -f deployment/kafka-monitor -n ${NAMESPACE}"
echo ""
echo "To access metrics via port-forward:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/kafka-monitor 8778:8778 9090:9090"
echo ""
echo "Then open in browser:"
echo "  http://localhost:8778/jolokia/"
echo "  http://localhost:9090/metrics"

