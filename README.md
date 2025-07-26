# RKE2 + Rancher Kubernetes Installation

This project provides a complete Ansible-based automation for installing and configuring a production-ready Kubernetes cluster using RKE2 (Rancher Kubernetes Engine 2) with Rancher management platform.

## 🎯 What This Project Delivers

A fully automated installation of:
- **RKE2 Kubernetes Cluster** with high availability
- **Rancher Management Platform** for cluster administration
- **MetalLB Load Balancer** for bare-metal load balancing
- **Kong Ingress Controllers** (internal and external)
- **cert-manager** for automatic SSL certificate management
- **NFS Storage Provisioner** for persistent storage
- **Monitoring Stack** (Prometheus, Grafana, AlertManager) - Optional
- **Logging & Tracing** (ELK Stack, Jaeger) - Optional

## 🖥️ Supported Operating Systems

### Ubuntu 20.04 LTS (Latest)
- **Status**: ✅ Fully Supported
- **Documentation**: [README-Ubuntu20.md](README-Ubuntu20.md)
- **Compatibility Check**: `./ubuntu20-compatibility-check.sh`
- **RKE2 Version**: v1.28.15+rke2r1
- **Rancher Version**: 2.10.3

### CentOS/RHEL 7-8 (Legacy)
- **Status**: ⚠️ Legacy Support
- **RKE2 Version**: v1.27.16+rke2r1
- **Rancher Version**: 2.10.3
- **Note**: Consider migrating to Ubuntu 20.04 for better long-term support

## 🚀 Quick Start

### For Ubuntu 20.04 LTS (Recommended)

1. **Check Compatibility**
   ```bash
   sudo ./ubuntu20-compatibility-check.sh
   ```

2. **Configure Inventory**
   ```bash
   # Edit inventory file with your node details
   vi inventory
   ```

3. **Run Installation**
   ```bash
   ansible-playbook -i inventory complete-installation-runbook.yml
   ```

4. **Access Services**
   - Rancher UI: `https://rancher.dellpc.in`
   - API Server (External): `https://192.168.1.200:6443`
   - Grafana: `https://grafana.dellpc.in`

### For CentOS/RHEL (Legacy)

Follow the original installation process with CentOS-specific configurations already included in the playbooks.

## 📋 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    External Access Layer                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Rancher UI     │  │  API Server     │  │  Applications   │ │
│  │ :443 (HTTPS)    │  │ :6443 (HTTPS)   │  │ :80/:443        │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                     MetalLB Load Balancer                      │
│                    (192.168.1.200-210)                         │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                    Kong Ingress Controllers                    │
│          Internal (kong-internal)  │  External (kong-external) │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                      RKE2 Kubernetes Cluster                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Master Node    │  │  Worker Node 1  │  │  Worker Node 2  │ │
│  │ 192.168.1.141   │  │ 192.168.1.142   │  │ 192.168.1.145   │ │
│  │ (Control Plane) │  │ (Workloads)     │  │ (Workloads)     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                        Storage Layer                           │
│              NFS Server (192.168.1.225)                        │
│            /volume3/size-4t-sub-2t1-dellpc-k8s                 │
└─────────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
install-rke2/
├── complete-installation-runbook.yml    # Main installation playbook
├── inventory                            # Ansible inventory file
├── ubuntu20-compatibility-check.sh      # Ubuntu 20.04 compatibility checker
├── README-Ubuntu20.md                   # Ubuntu 20.04 specific documentation
├── 
├── roles/                              # Ansible roles
│   ├── prerequisites/                  # System preparation
│   ├── rke2/                          # RKE2 installation
│   ├── networking/                     # MetalLB, Kong, cert-manager
│   ├── storage/                        # NFS storage provisioner
│   ├── rancher/                        # Rancher management platform
│   ├── monitoring/                     # Prometheus stack (optional)
│   └── logging-tracing/                # ELK stack + Jaeger (optional)
│
├── templates/                          # Configuration templates
│   ├── rke2-server-config.yaml.j2     # RKE2 server configuration
│   └── rke2-agent-config.yaml.j2      # RKE2 agent configuration
│
├── simple-startup-cluster.sh           # Cluster startup script
├── simple-shutdown-cluster.sh          # Cluster shutdown script
├── ARCHITECTURE.md                     # Detailed architecture documentation
├── CLUSTER_MANAGEMENT.md               # Cluster management guide
└── SECURITY_CHECKLIST.md              # Security best practices
```

## 🔧 Configuration

### Inventory Configuration

Update the `inventory` file with your environment details:

```ini
[rke2_nodes]
mgmt01 ansible_host=192.168.1.141 ansible_user=ubuntu node_role=server
worker01 ansible_host=192.168.1.142 ansible_user=ubuntu node_role=agent
worker02 ansible_host=192.168.1.145 ansible_user=ubuntu node_role=agent

[rke2_nodes:vars]
rke2_version=v1.28.15+rke2r1
rancher_hostname=rancher.dellpc.in
metallb_ip_pool=192.168.1.200-192.168.1.210
```

### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `rke2_version` | v1.28.15+rke2r1 | RKE2 version to install |
| `rancher_version` | 2.10.3 | Rancher version |
| `metallb_ip_pool` | 192.168.1.200-192.168.1.210 | LoadBalancer IP range |
| `rancher_hostname` | rancher.dellpc.in | Rancher UI hostname |
| `enable_monitoring` | false | Deploy monitoring stack |
| `enable_logging_tracing` | false | Deploy logging/tracing |

## 🔒 Security Features

- **TLS Everywhere**: All communications encrypted
- **RBAC**: Role-based access control
- **Network Policies**: Pod-to-pod security
- **Certificate Management**: Automated SSL certificates
- **Secrets Management**: Encrypted secret storage
- **AppArmor/SELinux**: Container security policies

## 📊 Monitoring & Observability

### Included Components (Optional)
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboards
- **AlertManager**: Alert routing and notification
- **Elasticsearch**: Log aggregation and search
- **Kibana**: Log visualization
- **Jaeger**: Distributed tracing

### Access URLs
- Grafana: `https://grafana.dellpc.in`
- Prometheus: `https://prometheus.dellpc.in`
- Kibana: `https://kibana.dellpc.in`
- Jaeger: `https://jaeger.dellpc.in`

## 🛠️ Management Tools

### Cluster Management Scripts
- `simple-startup-cluster.sh`: Start cluster nodes
- `simple-shutdown-cluster.sh`: Gracefully shutdown cluster

### Daily Operations
```bash
# Check cluster status
kubectl get nodes

# View all pods
kubectl get pods --all-namespaces

# Monitor resource usage
kubectl top nodes

# Check Rancher status
kubectl get pods -n cattle-system
```

## 🔍 Troubleshooting

### Common Issues

1. **Node Not Ready**
   ```bash
   kubectl describe node <node-name>
   journalctl -u rke2-server -f
   ```

2. **Pod Startup Issues**
   ```bash
   kubectl describe pod <pod-name>
   kubectl logs <pod-name>
   ```

3. **Network Connectivity**
   ```bash
   # Check MetalLB
   kubectl get pods -n metallb-system
   
   # Check Kong
   kubectl get pods -n kong-internal
   kubectl get pods -n kong-external
   ```

### Log Locations
- **RKE2 Logs**: `journalctl -u rke2-server` or `journalctl -u rke2-agent`
- **Container Logs**: `crictl logs <container-id>`
- **System Logs**: `/var/log/syslog` (Ubuntu) or `/var/log/messages` (CentOS)

## 🔄 Upgrading

### RKE2 Upgrade
```bash
# Update inventory with new version
rke2_version=v1.28.16+rke2r1

# Run upgrade playbook
ansible-playbook -i inventory complete-installation-runbook.yml --tags rke2
```

### Rancher Upgrade
```bash
# Update Rancher version in inventory
rancher_version=2.10.4

# Run Rancher upgrade
ansible-playbook -i inventory complete-installation-runbook.yml --tags rancher
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test changes on Ubuntu 20.04
4. Update documentation
5. Submit a pull request

## 📚 Additional Documentation

- [Ubuntu 20.04 Setup Guide](README-Ubuntu20.md)
- [Architecture Details](ARCHITECTURE.md)
- [Cluster Management](CLUSTER_MANAGEMENT.md)
- [Security Checklist](SECURITY_CHECKLIST.md)
- [Monitoring Setup](roles/monitoring/README.md)
- [Logging & Tracing](roles/logging-tracing/README.md)

## 📄 License

This project is provided as-is for educational and production use. Please review and test thoroughly before deploying in production environments.

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review the architecture documentation
3. Examine Ansible playbook logs
4. Consult the official RKE2 and Rancher documentation

---

**Version**: 2.1.0 (Ubuntu 20.04 Support)  
**Last Updated**: January 2025  
**Maintained By**: Infrastructure Team  
**Primary OS**: Ubuntu 20.04 LTS  
**Legacy Support**: CentOS/RHEL 7-8
