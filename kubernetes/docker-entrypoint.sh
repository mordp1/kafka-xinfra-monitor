#!/bin/sh

# Docker entrypoint script for Kafka Monitor
# Supports dynamic configuration via environment variables

set -e

echo "==================================="
echo "Kafka Monitor - Starting"
echo "==================================="

# Function to generate configuration file from environment variables
generate_config() {
    local config_file="${CONFIG_FILE:-config/xinfra-monitor.properties}"
    local temp_config="/tmp/runtime-config.properties"
    
    echo "Generating configuration from environment variables..."
    
    # Start JSON configuration
    cat > "$temp_config" <<EOF
{
  "single-cluster-monitor": {
    "class.name": "com.linkedin.xinfra.monitor.apps.SingleClusterMonitor",
    "topic": "${KAFKA_TOPIC}",
    "bootstrap.servers": "${KAFKA_BOOTSTRAP_SERVERS}",
    "security.protocol": "${KAFKA_SECURITY_PROTOCOL}",
EOF

    # Add SSL configuration if security protocol is SSL
    if [ "${KAFKA_SECURITY_PROTOCOL}" = "SSL" ] || [ "${KAFKA_SECURITY_PROTOCOL}" = "ssl" ]; then
        if [ -n "${KAFKA_SSL_KEYSTORE_LOCATION}" ]; then
            cat >> "$temp_config" <<EOF
    "ssl.keystore.location": "${KAFKA_SSL_KEYSTORE_LOCATION}",
    "ssl.keystore.password": "${KAFKA_SSL_KEYSTORE_PASSWORD}",
    "ssl.key.password": "${KAFKA_SSL_KEY_PASSWORD}",
EOF
        fi
        
        if [ -n "${KAFKA_SSL_TRUSTSTORE_LOCATION}" ]; then
            cat >> "$temp_config" <<EOF
    "ssl.truststore.location": "${KAFKA_SSL_TRUSTSTORE_LOCATION}",
    "ssl.truststore.password": "${KAFKA_SSL_TRUSTSTORE_PASSWORD}",
EOF
        fi
    fi

    # Continue with common configuration
    cat >> "$temp_config" <<EOF
    "request.timeout.ms": 9000,
    "produce.record.delay.ms": ${PRODUCE_RECORD_DELAY_MS},
    "topic-management.topicManagementEnabled": true,
    "topic-management.topicCreationEnabled": ${TOPIC_CREATION_ENABLED},
    "topic-management.replicationFactor": 1,
    "topic-management.partitionsToBrokersRatio": 2.0,
    "topic-management.rebalance.interval.ms": 600000,
    "topic-management.preferred.leader.election.check.interval.ms": 300000,
    "topic-management.topicFactory.props": {},
    "topic-management.topic.props": {
      "retention.ms": "3600000"
    },
    "produce.producer.props": {
      "client.id": "${KAFKA_CLIENT_ID}"
    },
    "consume.latency.sla.ms": "20000",
    "consume.consumer.props": {
      "group.id": "${KAFKA_CONSUMER_GROUP_ID}"
    }
  },

  "jolokia-service": {
    "class.name": "com.linkedin.xinfra.monitor.services.JolokiaService"
  },

  "reporter-service": {
    "class.name": "com.linkedin.xinfra.monitor.services.DefaultMetricsReporterService",
    "report.interval.sec": ${REPORT_INTERVAL_SEC},
    "report.metrics.list": [
        "kmf:type=kafka-monitor:offline-runnable-count",
        "kmf.services:type=produce-service,name=*:produce-availability-avg",
        "kmf.services:type=consume-service,name=*:consume-availability-avg",
        "kmf.services:type=produce-service,name=*:records-produced-total",
        "kmf.services:type=consume-service,name=*:records-consumed-total",
        "kmf.services:type=produce-service,name=*:records-produced-rate",
        "kmf.services:type=produce-service,name=*:produce-error-rate",
        "kmf.services:type=consume-service,name=*:consume-error-rate",
        "kmf.services:type=consume-service,name=*:records-lost-total",
        "kmf.services:type=consume-service,name=*:records-lost-rate",
        "kmf.services:type=consume-service,name=*:records-duplicated-total",
        "kmf.services:type=consume-service,name=*:records-delay-ms-avg"
    ]
  }
}
EOF

    echo "Configuration generated at: $temp_config"
    echo "==================================="
    cat "$temp_config"
    echo "==================================="
    
    # Use the generated config
    export CONFIG_FILE="$temp_config"
}

# SIGTERM handler
shutdown() {
    echo "Received shutdown signal, stopping Kafka Monitor..."
    pkill -TERM java
    wait $!
    exit 0
}

trap shutdown SIGTERM SIGINT

# Generate configuration from environment variables
generate_config

# Wait for Kafka to be available (optional)
if [ "${WAIT_FOR_KAFKA}" = "true" ]; then
    echo "Waiting for Kafka to be available..."
    sleep 10
fi

# Set JMX exporter if enabled
if [ "${ENABLE_JMX_EXPORTER}" = "true" ]; then
    # Set default port if not provided
    PROMETHEUS_EXPORTER_PORT="${PROMETHEUS_EXPORTER_PORT:-9090}"
    JMX_CONFIG="${JMX_CONFIG:-/opt/kafka-monitor/config/prometheus-exporter.yaml}"
    echo "Enabling Prometheus JMX Exporter on port ${PROMETHEUS_EXPORTER_PORT} with config ${JMX_CONFIG}"
    
    if [ -n "$JMX_CONFIG" ]; then
        export KAFKA_OPTS="-javaagent:/opt/jmx_prometheus_javaagent.jar=${PROMETHEUS_EXPORTER_PORT}:${JMX_CONFIG} ${KAFKA_OPTS:-}"
    else
        # Run without config file (uses default JMX exporter rules)
        export KAFKA_OPTS="-javaagent:/opt/jmx_prometheus_javaagent.jar=${PROMETHEUS_EXPORTER_PORT} ${KAFKA_OPTS:-}"
    fi
fi

# Start Kafka Monitor
echo "Starting Kafka Monitor with config: ${CONFIG_FILE}"
exec bin/xinfra-monitor-start.sh "${CONFIG_FILE}"