# Monitoring Role

This role deploys a complete monitoring stack for the RKE2 cluster, optimized for POC environments with 4GB RAM nodes.

## Components

- **Prometheus**: Metrics collection and storage with 1-day retention
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alerting and notifications
- **Node Exporter**: Node-level metrics
- **Kube State Metrics**: Cluster state metrics
- **Prometheus Operator**: Manages Prometheus resources

## POC Configuration

- **Log Retention**: 1 day
- **Volume Sizes**: Prometheus (1GB), Grafana (500MB), AlertManager (500MB)
- **Polling Frequency**: 5 minutes
- **Storage Class**: synostorage (configurable)
- **Resource Optimized**: For 4GB RAM nodes

## Usage

### Enable in Complete Installation

Set the monitoring variable in your inventory:

```ini
enable_monitoring=true
```

Then run the complete installation:

```bash
ansible-playbook -i inventory complete-installation-runbook.yml --tags monitoring
```

### Deploy Monitoring Only

If you want to deploy only the monitoring stack:

```bash
ansible-playbook -i inventory complete-installation-runbook.yml --tags monitoring
```

## Configuration Variables

All variables are defined in `roles/monitoring/defaults/main.yml` and can be overridden in your inventory:

### Core Settings
- `enable_monitoring`: Enable/disable monitoring deployment (default: false)
- `monitoring_storage_class`: Storage class for persistent volumes (default: synostorage)
- `monitoring_chart_version`: Helm chart version (default: 55.5.0)

### Retention & Polling
- `prometheus_retention`: Data retention period (default: 1d)
- `scrape_interval`: Metrics collection frequency (default: 5m)
- `evaluation_interval`: Rule evaluation frequency (default: 5m)

### Storage Sizes
- `prometheus_storage_size`: Prometheus data volume (default: 1Gi)
- `grafana_storage_size`: Grafana data volume (default: 500Mi)
- `alertmanager_storage_size`: AlertManager data volume (default: 500Mi)

### External Access
- `grafana_hostname`: Grafana external hostname (default: grafana.dellpc.in)
- `prometheus_hostname`: Prometheus external hostname (default: prometheus.dellpc.in)
- `alertmanager_hostname`: AlertManager external hostname (default: alertmanager.dellpc.in)
- `external_loadbalancer_ip`: Kong LoadBalancer IP (default: 192.168.1.201)

### Credentials
- `grafana_admin_user`: Grafana admin username (default: admin)
- `grafana_admin_password`: Grafana admin password (default: admin123)

## Access URLs

After deployment, configure DNS entries pointing to your Kong LoadBalancer IP (192.168.1.201):

- **Grafana**: https://grafana.dellpc.in (admin/admin123)
- **Prometheus**: https://prometheus.dellpc.in
- **AlertManager**: https://alertmanager.dellpc.in

## Resource Usage

Total resource allocation for 4GB nodes:

### CPU Limits
- Prometheus: 200m
- Grafana: 200m
- AlertManager: 100m
- Node Exporter: 100m
- Kube State Metrics: 100m
- Prometheus Operator: 200m
**Total CPU**: ~900m (0.9 cores)

### Memory Limits
- Prometheus: 512Mi
- Grafana: 256Mi
- AlertManager: 256Mi
- Node Exporter: 128Mi
- Kube State Metrics: 128Mi
- Prometheus Operator: 256Mi
**Total Memory**: ~1.5Gi

### Storage Requirements
- Prometheus: 1Gi (data)
- Grafana: 500Mi (config/dashboards)
- AlertManager: 500Mi (alerts)
**Total Storage**: ~2Gi

## DNS Configuration Example

Add these entries to your DNS server or local hosts file:

```
192.168.1.201  grafana.dellpc.in
192.168.1.201  prometheus.dellpc.in
192.168.1.201  alertmanager.dellpc.in
```

## Dependencies

- RKE2 cluster must be running
- Kong external ingress controller must be deployed
- Storage provisioner (synostorage) must be available
- Helm must be installed on the master node

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n monitoring
```

### Check Storage
```bash
kubectl get pvc -n monitoring
```

### Check Ingress
```bash
kubectl get ingress -n monitoring
```

### Access Logs
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```
