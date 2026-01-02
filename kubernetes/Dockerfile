FROM alpine:3.22.2

LABEL description="Kafka Monitor (Xinfra Monitor)"

WORKDIR /opt/kafka-monitor

ARG JMX_EXPORTER_VERSION=1.0.1

# Single optimized layer: download, copy, configure
ADD https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar /opt/jmx_prometheus_javaagent.jar

COPY build/libs/kafka-monitor-*.jar build/libs/
COPY build/dependant-libs/ build/dependant-libs/
COPY bin/ bin/
COPY config/ config/
COPY webapp/ webapp/
COPY kubernetes/docker-entrypoint.sh /docker-entrypoint.sh

# Single RUN: install deps, create user, set permissions
RUN apk add --no-cache openjdk21-jre bash && \
    chmod +x /docker-entrypoint.sh && \
    mkdir -p certs && \
    addgroup -S kmf && \
    adduser -S kmf -G kmf && \
    chown -R kmf:kmf /opt/kafka-monitor /opt/jmx_prometheus_javaagent.jar && \
    rm -rf /var/cache/apk/*

USER kmf

ENV KAFKA_BOOTSTRAP_SERVERS="localhost:9092" \
    KAFKA_TOPIC="xinfra-monitor-topic" \
    KAFKA_SECURITY_PROTOCOL="PLAINTEXT" \
    KAFKA_CLIENT_ID="xinfra-monitor" \
    KAFKA_CONSUMER_GROUP_ID="xinfra-monitor" \
    TOPIC_CREATION_ENABLED="false" \
    PRODUCE_RECORD_DELAY_MS="100" \
    REPORT_INTERVAL_SEC="1" \
    CONFIG_FILE="config/xinfra-monitor.properties"

EXPOSE 8778


ENTRYPOINT ["/docker-entrypoint.sh"]
