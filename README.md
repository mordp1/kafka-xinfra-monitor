# Kafka Monitor

Docker and Kubernetes deployment configurations for Kafka Monitor ([Xinfra Monitor](https://github.com/linkedin/kafka-monitor))

## About This Fork

This is an updated version of Kafka Monitor (Xinfra Monitor) focused on:

- **JDK 21 compatibility** - Updated to run on OpenJDK 21
- **Modern Kafka support** - Compatible with recent Kafka versions that run without ZooKeeper (KRaft mode)
- **Container-ready** - Docker and Kubernetes deployment configurations included

> **Note**: This project is a work in progress. The primary goal is to provide JDK 21 and ZooKeeper-free Kafka compatibility. Additional code cleanup and improvements are welcome contributions!

**Contributions are welcome!** Feel free to help improve the codebase, add features, or fix issues.

> **Tested with**: OpenJDK 21.0.8 (2025-07-15)


## Quick Start - Local Development

### 1. Build the Application

```bash
# From project root
./gradlew clean build -x test
```

### 2. Build Docker Image

```bash
docker buildx build --platform linux/amd64 -t kafka-monitor:1.2 .
```

2.1 Push image


### 3. Run with Docker Compose

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f kafka-monitor

# Stop services
docker-compose down
```

## Docker Compose Configuration

### Basic Setup (PLAINTEXT)

Edit `docker-compose.yml`:

```yaml
services:
  kafka-monitor:
    environment:
      KAFKA_BOOTSTRAP_SERVERS: "localhost:9092"
      KAFKA_TOPIC: "xinfra-monitor-topic"
      KAFKA_SECURITY_PROTOCOL: "PLAINTEXT"
```

## Running Without Docker

### Direct Execution

```bash
# Edit configuration
vim kubernetes/xinfra-monitor.properties

# Start monitor
bin/xinfra-monitor-start.sh kubernetes/xinfra-monitor.properties
```

### Configuration Example (mTLS)

```json
{
  "single-cluster-monitor": {
    "bootstrap.servers": "broker:9093",
    "security.protocol": "SSL",
    "ssl.keystore.location": "/path/to/user.p12",
    "ssl.keystore.password": "PASSWORD",
    "ssl.key.password": "PASSWORD"
  }
}
```

## Kubernetes Deployment Example

### 1. Create Kafka Resources

```bash
# Create KafkaUser (generates certificates)
kubectl apply -f kubernetes/kafkaUser-example.yaml -n kafka-monitoring

# Create KafkaTopics
kubectl apply -f kubernetes/kafkaTopics.yaml -n kafka-monitoring

# Wait for secrets to be generated
kubectl get secret kafka-monitor-user -n kafka-monitoring
```

### 2. Deploy Kafka Monitor

```bash
# Apply deployment
kubectl apply -f kubernetes/deploy.yaml -n kafka-monitoring

# Check pod status
kubectl get pods -n kafka-monitoring -l app=kafka-monitor

# View logs
kubectl logs -n kafka-monitoring -l app=kafka-monitor -f
```

### 3. Access Metrics

```bash
# Port forward
kubectl port-forward -n kafka-monitoring svc/kafka-monitor 8778:8778 9090:9090

# Jolokia metrics
curl http://localhost:8778/jolokia/list

# Prometheus metrics
curl http://localhost:9090/metrics | grep kafka_monitor
```

## Available Endpoints

### Jolokia (Port 8778)

```bash
# Health check
curl http://localhost:8778/jolokia/version
```

### Prometheus Metrics (Port 9090)

```bash
# All metrics
curl http://localhost:9090/metrics
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` | Kafka broker list |
| `KAFKA_TOPIC` | `xinfra-monitor-topic` | Monitoring topic name |
| `KAFKA_SECURITY_PROTOCOL` | `PLAINTEXT` | Protocol: PLAINTEXT, SSL, SASL_SSL |
| `KAFKA_CLIENT_ID` | `xinfra-monitor` | Client identifier |
| `KAFKA_CONSUMER_GROUP_ID` | `xinfra-monitor` | Consumer group |
| `KAFKA_SSL_KEYSTORE_LOCATION` | - | Path to keystore (mTLS) |
| `KAFKA_SSL_KEYSTORE_PASSWORD` | - | Keystore password |
| `KAFKA_SSL_KEY_PASSWORD` | - | Key password |
| `ENABLE_JMX_EXPORTER` | `true` | Enable Prometheus exporter |
| `PROMETHEUS_EXPORTER_PORT` | `9090` | Prometheus metrics port |
| `TOPIC_CREATION_ENABLED` | `false` | Auto-create topic |


# Quick Start Guide - Local Kubernetes Testing ( Using Kind)

This is a quick reference guide for setting up and testing Kafka Xinfra Monitor with Strimzi on a local Kubernetes cluster.

## Prerequisites

```bash
# Install kind (Kubernetes in Docker)
brew install kind  # macOS
# or visit https://kind.sigs.k8s.io/docs/user/quick-start/

# Verify installations
kind version
kubectl version --client
docker --version
```

## One-Command Setup

Run everything in one go:

```bash
./setup-all.sh
```

This will:
1. Create a local Kubernetes cluster (kind)
2. Build the Kafka Monitor Docker image
3. Install Strimzi Operator
4. Deploy a Kafka cluster
5. Deploy Kafka Monitor
6. Run tests


## Access Metrics

Port-forward the service:

```bash
kubectl port-forward -n kafka-monitor svc/kafka-monitor 8778:8778 9090:9090
```

Then access:
- **Jolokia**: http://localhost:8778/jolokia/
- **Prometheus metrics**: http://localhost:9090/metrics

## View Logs

```bash
# Monitor logs
kubectl logs -f deployment/kafka-monitor -n kafka-monitor

# Kafka logs
kubectl logs -f -n kafka -l strimzi.io/name=my-cluster-kafka
```

## Useful Commands

```bash
# Check all resources
kubectl get all -n kafka
kubectl get all -n kafka-monitor

# Check Kafka cluster status
kubectl get kafka -n kafka

# Check topics
kubectl get kafkatopic -n kafka

# Describe pod for troubleshooting
kubectl describe pod -n kafka-monitor -l app=kafka-monitor
```

## Cleanup

Remove everything:

```bash
./local-k8s/cleanup.sh
```

Or manually:

```bash
kind delete cluster --name kafka-test
docker stop kind-registry
docker rm kind-registry
```

## Troubleshooting

### Cluster not starting
- Ensure Docker has enough resources (4GB RAM minimum recommended)
- Check: `docker ps` and `docker stats`

### Image build fails
- Ensure Gradle build succeeds: `./gradlew clean build -x test`
- Check Java version (JDK 21 recommended)

### Kafka pods not ready
- Wait longer (Kafka can take 2-5 minutes to start)
- Check: `kubectl describe pod -n kafka <pod-name>`
- Check events: `kubectl get events -n kafka --sort-by='.lastTimestamp'`

### Monitor not connecting
- Verify Kafka is ready: `kubectl get kafka -n kafka`
- Check monitor logs: `kubectl logs -f deployment/kafka-monitor -n kafka-monitor`
- Verify service name: `kubectl get svc -n kafka | grep bootstrap`

## Configuration

Key configuration files:
- `local-k8s/kafka-cluster.yaml` - Kafka cluster configuration
- `local-k8s/kafka-monitor-deployment.yaml` - Monitor deployment configuration
