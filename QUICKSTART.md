# Quick Start Guide - Local Kubernetes Testing

This is a quick reference guide for setting up and testing Kafka Xinfra Monitor with Strimzi 4.0 on a local Kubernetes cluster.

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
cd kafka-xinfra-monitor
./local-k8s/setup-all.sh
```

This will:
1. Create a local Kubernetes cluster (kind)
2. Build the Kafka Monitor Docker image
3. Install Strimzi Operator 4.0
4. Deploy a Kafka cluster
5. Deploy Kafka Monitor
6. Run tests

## Step-by-Step Setup

If you prefer to run steps individually:

### 1. Set up Kubernetes Cluster

```bash
./local-k8s-setup.sh
```

Creates a kind cluster named `kafka-test` with a local registry.

### 2. Build and Push Image

```bash
./build-and-push.sh
```

Builds the application and Docker image, then loads it into the kind cluster.

### 3. Install Strimzi Operator

```bash
./install-strimzi.sh
```

Installs Strimzi Cluster Operator version 4.0.0.

### 4. Deploy Kafka Cluster

```bash
./local-k8s/deploy-kafka.sh
```

Deploys a Kafka 3.7.0 cluster with 1 replica (suitable for local testing).

### 5. Deploy Kafka Monitor

```bash
./local-k8s/deploy-monitor.sh
```

Deploys the Kafka Xinfra Monitor application.

### 6. Test Deployment

```bash
./local-k8s/test.sh
```

Runs basic health checks and tests.

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

For detailed documentation, see: `local-k8s/README.md`

