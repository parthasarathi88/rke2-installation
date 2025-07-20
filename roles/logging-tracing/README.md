# Logging and Tracing Role

This Ansible role deploys a comprehensive logging and distributed tracing solution for the RKE2 cluster using:

- **ELK Stack**: Elasticsearch, Logstash, Kibana for log aggregation and analysis
- **Filebeat**: Log collection from all cluster nodes
- **Jaeger**: Distributed tracing for application performance monitoring

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Applications  │    │  Kubernetes     │    │   Jaeger        │
│                 │───▶│  Logs           │───▶│  Tracing        │
│ (OpenTelemetry) │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Filebeat      │───▶│   Logstash      │───▶│ Elasticsearch   │
│  (DaemonSet)    │    │ (Processing)    │    │   (Storage)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │     Kibana      │
                                               │ (Visualization) │
                                               └─────────────────┘
```

## Components

### Elasticsearch
- **Purpose**: Search engine and log storage
- **Configuration**: Single node deployment for POC
- **Storage**: 2Gi persistent volume using synostorage
- **Resources**: 1-2Gi memory, 0.5-1 CPU
- **Access**: elasticsearch.dellpc.in (via Kong ingress)

### Kibana
- **Purpose**: Log visualization and dashboard creation
- **Configuration**: Connected to Elasticsearch
- **Resources**: 512Mi-1Gi memory, 0.2-0.5 CPU
- **Access**: kibana.dellpc.in (via Kong ingress)

### Logstash
- **Purpose**: Log processing and enrichment
- **Configuration**: Processes logs from Filebeat and HTTP inputs
- **Resources**: 512Mi-1Gi memory, 0.2-0.5 CPU
- **Inputs**: Beats (port 5044), HTTP (port 8080)

### Filebeat
- **Purpose**: Log collection from container logs
- **Configuration**: DaemonSet running on all nodes
- **Resources**: 100-200Mi memory, 0.1-0.2 CPU per node
- **Collection**: /var/log/containers/*.log

### Jaeger
- **Purpose**: Distributed tracing for applications
- **Configuration**: All-in-one deployment for POC
- **Resources**: 256-512Mi memory, 0.2-0.5 CPU
- **Access**: jaeger.dellpc.in (via Kong ingress)
- **Storage**: In-memory (50,000 traces)

## Prerequisites

- RKE2 cluster with Kong ingress controller
- synostorage storage class available
- Helm 3.x installed
- kubernetes.core Ansible collection

## Usage

### Deploy Logging and Tracing Stack

```yaml
- name: Deploy logging and tracing
  include_role:
    name: logging-tracing
  tags:
    - logging
    - tracing
```

### Deploy Only Logging (ELK Stack)

```yaml
- name: Deploy logging only
  include_role:
    name: logging-tracing
  tags:
    - logging
```

### Deploy Only Tracing (Jaeger)

```yaml
- name: Deploy tracing only
  include_role:
    name: logging-tracing
  tags:
    - tracing
```

## Configuration

### Storage Configuration
```yaml
# Adjust storage sizes
elasticsearch_storage_size: "5Gi"  # Increase for production
```

### Resource Configuration
```yaml
# Adjust for different node sizes
elasticsearch_memory_limit: "4Gi"   # For larger nodes
kibana_memory_limit: "2Gi"          # For larger nodes
```

### External Access
```yaml
# Configure external URLs
kibana_external_url: "logs.mycompany.com"
jaeger_external_url: "tracing.mycompany.com"
elasticsearch_external_url: "search.mycompany.com"
```

## Access URLs

After deployment, the following services will be available:

- **Kibana Dashboard**: https://kibana.dellpc.in
- **Jaeger Tracing UI**: https://jaeger.dellpc.in
- **Elasticsearch API**: https://elasticsearch.dellpc.in

## Getting Started

### 1. Access Kibana
1. Navigate to https://kibana.dellpc.in
2. Go to "Stack Management" → "Index Patterns"
3. Create index pattern: `logstash-logs-*`
4. Set time field: `@timestamp`

### 2. Create Log Dashboards
1. Go to "Analytics" → "Discover"
2. Explore your logs with the created index pattern
3. Create visualizations in "Analytics" → "Visualize"
4. Build dashboards in "Analytics" → "Dashboard"

### 3. Set Up Application Tracing
```yaml
# Example: Enable tracing in your application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: JAEGER_AGENT_HOST
          value: "jaeger-agent.logging-tracing.svc.cluster.local"
        - name: JAEGER_AGENT_PORT
          value: "6831"
```

## Log Collection

The Filebeat DaemonSet automatically collects logs from:

- All container logs in `/var/log/containers/`
- Kubernetes metadata is automatically added
- Logs are enriched with pod, namespace, and node information

### Log Format
```json
{
  "@timestamp": "2025-07-17T10:30:00.000Z",
  "message": "Application log message",
  "kubernetes": {
    "pod": {"name": "my-app-123"},
    "namespace": "default",
    "container": {"name": "app"}
  },
  "cluster": "rke2-poc"
}
```

## Monitoring and Alerting

### Kibana Alerting
1. Go to "Stack Management" → "Rules and Connectors"
2. Create alerting rules for:
   - High error rates
   - Application downtime
   - Resource usage spikes

### Jaeger Monitoring
- Monitor trace latencies and error rates
- Identify performance bottlenecks
- Track service dependencies

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n logging-tracing
```

### View Logs
```bash
# Elasticsearch logs
kubectl logs -n logging-tracing deployment/elasticsearch-master

# Kibana logs
kubectl logs -n logging-tracing deployment/kibana-kibana

# Logstash logs
kubectl logs -n logging-tracing deployment/logstash-logstash

# Filebeat logs
kubectl logs -n logging-tracing daemonset/filebeat-filebeat

# Jaeger logs
kubectl logs -n logging-tracing deployment/jaeger
```

### Test Connectivity
```bash
# Test Elasticsearch
kubectl exec -n logging-tracing deployment/elasticsearch-master -- curl localhost:9200

# Test Kibana
kubectl exec -n logging-tracing deployment/kibana-kibana -- curl localhost:5601

# Test Logstash
kubectl exec -n logging-tracing deployment/logstash-logstash -- curl localhost:9600
```

## Performance Tuning

### For Production Use
```yaml
# Increase replicas
elasticsearch_replicas: 3
logstash_replicas: 2

# Increase resources
elasticsearch_memory_limit: "8Gi"
elasticsearch_storage_size: "100Gi"

# Enable persistent storage for Jaeger
# (Consider using Elasticsearch backend)
```

### For Larger Clusters
```yaml
# Adjust Filebeat resources
filebeat_memory_limit: "500Mi"
filebeat_cpu_limit: "500m"

# Increase Logstash processing
logstash_replicas: 3
logstash_memory_limit: "2Gi"
```

## Security Considerations

### Current POC Configuration
- Security features disabled for simplicity
- No authentication required
- Internal cluster communication only

### Production Recommendations
- Enable Elasticsearch security features
- Configure SSL/TLS encryption
- Implement RBAC and authentication
- Use secrets for sensitive configuration

## Integration Examples

### Application Logging
```yaml
# Log to stdout/stderr, Filebeat will collect automatically
logger.info("User login successful", extra={"user_id": 123})
```

### Distributed Tracing
```python
# Python example with OpenTelemetry
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configure Jaeger exporter
jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger-agent.logging-tracing.svc.cluster.local",
    agent_port=6831,
)

# Set up tracing
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

span_processor = BatchSpanProcessor(jaeger_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Create spans
with tracer.start_as_current_span("user-service") as span:
    span.set_attribute("user.id", "123")
    # Your application logic here
```

## Maintenance

### Regular Tasks
- Monitor disk usage for Elasticsearch
- Review and optimize Kibana dashboards
- Clean up old indices periodically
- Monitor resource usage and scale as needed

### Backup Strategy
- Elasticsearch snapshots for log data
- Export Kibana dashboards and visualizations
- Document custom Logstash configurations
