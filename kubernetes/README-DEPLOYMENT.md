# Kafka Monitor Deployment Guide (mTLS)

Complete deployment guide for Kafka Monitor with mTLS authentication to Kafka cluster.

## Prerequisites

1. **KafkaUser created** (`kafkaUser-example.yaml`)
2. **KafkaTopics created** (`kafkaTopics.yaml`)
3. **Strimzi Operator installed** in cluster
4. **Secrets available**:
   - `kafka-monitor-user` (user certificate)
   - `kafka-cluster-cluster-ca-cert` (cluster CA)

## Deployment Steps

### 1. Create KafkaUser (if not exists)

```bash
kubectl apply -f kubernetes/kafkaUser-example.yaml
```

Wait for the user to be ready and certificates to be generated:

```bash
kubectl get kafkauser kafka-monitor-user -n kafka-monitoring -w
```

### 2. Create KafkaTopics (if not exists)

```bash
kubectl apply -f kubernetes/kafkaTopics.yaml
```

Verify topics:

```bash
kubectl get kafkatopic -n kafka-monitoring | grep kafka-monitor
```

### 3. Verify Secrets

Check that the secrets were created by Strimzi:

```bash
# User certificate secret
kubectl get secret kafka-monitor-user -n kafka-monitoring
kubectl describe secret kafka-monitor-user -n kafka-monitoring

# Cluster CA secret
kubectl get secret kafka-cluster-cluster-ca-cert -n kafka-monitoring
```

Expected keys in secrets:
- `kafka-monitor-user`: `user.p12`, `user.password`, `user.crt`, `user.key`
- `kafka-cluster-cluster-ca-cert`: `ca.p12`, `ca.password`, `ca.crt`

### 4. Build and Push Docker Image

```bash
# Build the image
docker build -f kubernetes/Dockerfile -t your-registry.azurecr.io/kafka-monitor:latest .

# Push to registry
docker push your-registry.azurecr.io/kafka-monitor:latest
```

### 5. Update Deploy Configuration

Edit `kubernetes/deploy.yaml` and update:

```yaml
# Line ~100: Update image reference
image: your-registry.azurecr.io/kafka-monitor:latest

# Line ~10: Verify bootstrap servers (if different)
bootstrap.servers: "kafka-cluster-kafka-bootstrap.kafka-monitoring.svc.cluster.local:9093"
```

### 6. Deploy Kafka Monitor

```bash
kubectl apply -f kubernetes/deploy.yaml
```

This creates:
- ConfigMap with monitor configuration
- Deployment (1 replica)
- Service (ClusterIP)
- ServiceAccount
- ServiceMonitor (for Prometheus)

### 7. Verify Deployment

```bash
# Check pod status
kubectl get pods -n kafka-monitoring -l app=kafka-monitor

# Check logs
kubectl logs -n kafka-monitoring -l app=kafka-monitor -f

# Check service
kubectl get svc kafka-monitor -n kafka-monitoring
```

### 8. Test Connectivity

```bash
# Port forward to access Jolokia
kubectl port-forward -n kafka-monitoring svc/kafka-monitor 8778:8778

# Test Jolokia endpoint
curl http://localhost:8778/jolokia/version

# Check metrics
curl http://localhost:8778/jolokia/read/kmf.services:type=produce-service,name=*
```

### 9. Verify Monitoring

```bash
# Port forward for Prometheus metrics
kubectl port-forward -n kafka-monitoring svc/kafka-monitor 9090:9090

# Check Prometheus metrics
curl http://localhost:9090/metrics | grep kafka_monitor
```

## Configuration Details

### mTLS Configuration

The deployment uses mTLS with:

**Truststore** (Cluster CA):
- Location: `/opt/kafka-monitor/certs/truststore.p12`
- Secret: `kafka-cluster-cluster-ca-cert`
- Key: `ca.p12`

**Keystore** (User Certificate):
- Location: `/opt/kafka-monitor/certs/user.p12`
- Secret: `kafka-monitor-user`
- Key: `user.p12`

**Passwords** (from secrets):
- Truststore password: From `kafka-cluster-cluster-ca-cert/ca.password`
- Keystore password: From `kafka-monitor-user/user.password`

### Environment Variables

The deployment sets these key environment variables:

```bash
KAFKA_BOOTSTRAP_SERVERS=kafka-cluster-kafka-bootstrap.kafka-monitoring.svc.cluster.local:9093
KAFKA_SECURITY_PROTOCOL=SSL
KAFKA_CLIENT_ID=kafka-monitor
TOPIC_CREATION_ENABLED=false
```

## Metrics Available

### Jolokia Metrics (Port 8778)

Access via: `http://kafka-monitor:8778/jolokia/`

Key metrics:
- `kmf.services:type=produce-service,name=*:produce-availability-avg`
- `kmf.services:type=consume-service,name=*:consume-availability-avg`
- `kmf.services:type=consume-service,name=*:records-lost-total`
- `kmf.services:type=consume-service,name=*:records-delay-ms-avg`

### Prometheus Metrics (Port 9090)

Access via: `http://kafka-monitor:9090/metrics`

Exported via JMX exporter, prefixed with `kafka_monitor_`:
- `kafka_monitor_produce_availability_avg`
- `kafka_monitor_consume_availability_avg`
- `kafka_monitor_records_produced_total`
- `kafka_monitor_records_consumed_total`

## Troubleshooting

### Pod Not Starting

```bash
# Check events
kubectl describe pod -n kafka-monitoring -l app=kafka-monitor

# Check logs
kubectl logs -n kafka-monitoring -l app=kafka-monitor --previous
```

### Certificate Issues

```bash
# Verify secrets exist and have correct keys
kubectl get secret kafka-monitor-user -n kafka-monitoring -o yaml
kubectl get secret kafka-cluster-cluster-ca-cert -n kafka-monitoring -o yaml

# Check certificate expiration
kubectl get secret kafka-monitor-user -n kafka-monitoring -o jsonpath='{.data.user\.crt}' | base64 -d | openssl x509 -noout -dates
```

### Connection Issues

```bash
# Test DNS resolution from pod
kubectl exec -it -n kafka-monitoring deploy/kafka-monitor -- nslookup kafka-cluster-kafka-bootstrap.kafka-monitoring.svc.cluster.local

# Test SSL connection
kubectl exec -it -n kafka-monitoring deploy/kafka-monitor -- openssl s_client -connect kafka-cluster-kafka-bootstrap.kafka-monitoring.svc.cluster.local:9093 -showcerts
```

### Permission Issues

Check KafkaUser ACLs:

```bash
kubectl get kafkauser kafka-monitor-user -n kafka-monitoring -o yaml
```

Ensure ACLs include:
- Topic access: `kafka-monitor-*` (All operations)
- Group access: `kafka-monitor-*` (All operations)
- Cluster access: All operations

### Metrics Not Showing

```bash
# Check JMX exporter is working
kubectl logs -n kafka-monitoring -l app=kafka-monitor | grep jmx

# Verify Prometheus scraping
kubectl get servicemonitor kafka-monitor -n kafka-monitoring -o yaml
```

## Prometheus Queries

Example PromQL queries:

```promql
# Produce availability
kafka_monitor_produce_availability_avg

# Consume availability
kafka_monitor_consume_availability_avg

# Records produced per second
rate(kafka_monitor_records_produced_total[5m])

# Records consumed per second
rate(kafka_monitor_records_consumed_total[5m])

# Message lag
kafka_monitor_records_delay_ms_avg

# Lost records
increase(kafka_monitor_records_lost_total[1h])
```

## Grafana Dashboard

Import the Xinfra Monitor dashboard or create custom panels:

1. **Availability Panel**: Show produce/consume availability over time
2. **Throughput Panel**: Records produced/consumed rates
3. **Latency Panel**: End-to-end message delay
4. **Error Panel**: Lost and duplicated records

## Scaling

To run multiple instances:

```yaml
spec:
  replicas: 3  # Increase from 1
```

**Note**: Multiple instances will produce/consume independently. Ensure consumer group handling is appropriate.

## Cleanup

```bash
# Delete deployment
kubectl delete -f kubernetes/deploy.yaml

# Optionally delete topics
kubectl delete -f kubernetes/kafkaTopics.yaml

# Optionally delete user (this will also delete the secret)
kubectl delete -f kubernetes/kafkaUser-example.yaml
```

## Security Considerations

1. **Secrets**: Passwords are stored in Kubernetes secrets and injected as environment variables
2. **Non-root**: Runs as user `kmf` (non-root)
3. **Read-only**: Certificate volumes are mounted read-only
4. **Network**: Service is ClusterIP only (not exposed externally)
5. **Resources**: Memory and CPU limits defined

## Additional Resources

- [Xinfra Monitor Documentation](https://github.com/linkedin/kafka-monitor)
- [Strimzi Documentation](https://strimzi.io/docs/)
- [Kafka Security](https://kafka.apache.org/documentation/#security)
