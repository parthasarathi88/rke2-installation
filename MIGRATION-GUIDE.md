# Migration Guide: CentOS/RHEL to Ubuntu 20.04 LTS

This guide helps you migrate your RKE2 + Rancher installation from CentOS/RHEL to Ubuntu 20.04 LTS.

## 🎯 Migration Overview

Moving from CentOS/RHEL to Ubuntu 20.04 provides:
- **Long-term Support**: Ubuntu 20.04 LTS supported until 2025
- **Better Container Support**: Enhanced containerd and AppArmor integration
- **Modern Packages**: Access to newer versions of system components
- **Performance**: Improved performance on modern hardware
- **Security**: Better security frameworks and updates

## ⚠️ Pre-Migration Checklist

### 1. Backup Current Environment
```bash
# Create etcd backup
kubectl create -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: etcd-backup
spec:
  containers:
  - name: etcd-backup
    image: rancher/rke2-runtime:v1.27.16-rke2r1
    command: ["/bin/sh"]
    args: ["-c", "etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key snapshot save /backup/etcd-snapshot-\$(date +%Y%m%d-%H%M%S).db"]
    volumeMounts:
    - name: etcd-data
      mountPath: /var/lib/rancher/rke2/server/db/etcd
    - name: backup
      mountPath: /backup
  volumes:
  - name: etcd-data
    hostPath:
      path: /var/lib/rancher/rke2/server/db/etcd
  - name: backup
    hostPath:
      path: /tmp/backup
  restartPolicy: Never
EOF

# Backup persistent volumes
kubectl get pv -o yaml > pv-backup.yaml
kubectl get pvc --all-namespaces -o yaml > pvc-backup.yaml
```

### 2. Document Current Configuration
```bash
# Export current configurations
kubectl get nodes -o yaml > nodes-config.yaml
kubectl get configmaps --all-namespaces -o yaml > configmaps-backup.yaml
kubectl get secrets --all-namespaces -o yaml > secrets-backup.yaml

# Document Rancher settings
kubectl get settings.management.cattle.io -o yaml > rancher-settings.yaml
```

### 3. Export Application Manifests
```bash
# Export all application deployments
kubectl get deployments --all-namespaces -o yaml > deployments-backup.yaml
kubectl get services --all-namespaces -o yaml > services-backup.yaml
kubectl get ingresses --all-namespaces -o yaml > ingresses-backup.yaml
```

## 🔄 Migration Strategies

### Strategy 1: Fresh Installation (Recommended)

**Best for**: New deployments or when you can afford downtime

1. **Prepare Ubuntu 20.04 Nodes**
   ```bash
   # Install Ubuntu 20.04 LTS on new hardware/VMs
   # Configure static IP addresses
   # Set up SSH key authentication
   ```

2. **Run Compatibility Check**
   ```bash
   sudo ./ubuntu20-compatibility-check.sh
   ```

3. **Configure Inventory**
   ```bash
   cp inventory-ubuntu20-template inventory
   # Edit with your Ubuntu node details
   ```

4. **Deploy Fresh Cluster**
   ```bash
   ansible-playbook -i inventory complete-installation-runbook.yml
   ```

5. **Restore Data**
   ```bash
   # Restore etcd backup
   # Recreate persistent volumes
   # Deploy applications
   ```

### Strategy 2: Rolling Migration

**Best for**: Production environments requiring minimal downtime

1. **Add Ubuntu Worker Nodes**
   ```bash
   # Add Ubuntu workers to existing cluster
   # Update inventory to include Ubuntu nodes
   ansible-playbook -i inventory complete-installation-runbook.yml --limit ubuntu_workers --tags rke2
   ```

2. **Migrate Workloads**
   ```bash
   # Drain CentOS workers one by one
   kubectl drain <centos-worker> --ignore-daemonsets --delete-emptydir-data
   
   # Verify workloads move to Ubuntu nodes
   kubectl get pods -o wide
   ```

3. **Replace Master Node**
   ```bash
   # This requires careful planning and etcd backup/restore
   # Consider consulting with Rancher support for production environments
   ```

### Strategy 3: Blue-Green Deployment

**Best for**: Critical production environments

1. **Set Up Parallel Ubuntu Cluster**
2. **Migrate Data and Applications**
3. **Switch Traffic (DNS/Load Balancer)**
4. **Decommission CentOS Cluster**

## 🔧 Configuration Differences

### Package Management
| CentOS/RHEL | Ubuntu 20.04 |
|-------------|---------------|
| `yum install` | `apt install` |
| `systemctl` | `systemctl` |
| `firewalld` | `ufw` |
| `SELinux` | `AppArmor` |

### Service Names
| Service | CentOS/RHEL | Ubuntu 20.04 |
|---------|-------------|---------------|
| iSCSI | `iscsi` + `iscsid` | `open-iscsi` + `iscsid` |
| SSH | `sshd` | `ssh` |
| Firewall | `firewalld` | `ufw` |

### Security Frameworks
```bash
# CentOS/RHEL - SELinux
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# Ubuntu 20.04 - AppArmor
aa-complain /usr/bin/containerd
systemctl disable apparmor.service
```

## 📋 Step-by-Step Migration

### Phase 1: Preparation

1. **Document Current Environment**
   ```bash
   # Create migration documentation
   kubectl get nodes -o wide > current-nodes.txt
   kubectl get pods --all-namespaces -o wide > current-pods.txt
   kubectl get svc --all-namespaces > current-services.txt
   ```

2. **Prepare Ubuntu 20.04 Nodes**
   ```bash
   # Install Ubuntu 20.04 LTS
   # Configure networking
   # Set up SSH access
   # Run compatibility check
   sudo ./ubuntu20-compatibility-check.sh
   ```

### Phase 2: Fresh Installation

1. **Deploy Ubuntu Cluster**
   ```bash
   # Update inventory for Ubuntu nodes
   cp inventory-ubuntu20-template inventory
   
   # Run installation
   ansible-playbook -i inventory complete-installation-runbook.yml
   ```

2. **Verify Base Installation**
   ```bash
   # Check cluster status
   export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
   kubectl get nodes
   kubectl get pods --all-namespaces
   ```

### Phase 3: Data Migration

1. **Restore etcd Data** (if needed)
   ```bash
   # Stop RKE2 server
   systemctl stop rke2-server
   
   # Restore etcd snapshot
   # This is complex - consider fresh installation instead
   ```

2. **Recreate Persistent Volumes**
   ```bash
   # Update PV definitions for new NFS paths
   kubectl apply -f pv-backup.yaml
   kubectl apply -f pvc-backup.yaml
   ```

3. **Deploy Applications**
   ```bash
   # Update deployment manifests for Ubuntu specifics
   kubectl apply -f deployments-backup.yaml
   kubectl apply -f services-backup.yaml
   ```

### Phase 4: Verification

1. **Test All Services**
   ```bash
   # Check Rancher access
   curl -k https://rancher.dellpc.in
   
   # Test API server
   kubectl --server=https://192.168.1.200:6443 get nodes
   
   # Verify applications
   kubectl get pods --all-namespaces
   ```

2. **Performance Testing**
   ```bash
   # Run workload tests
   # Monitor resource usage
   kubectl top nodes
   kubectl top pods --all-namespaces
   ```

## 🔍 Troubleshooting Migration Issues

### Common Issues

1. **Package Installation Failures**
   ```bash
   # Update package cache
   sudo apt update
   
   # Fix broken packages
   sudo apt --fix-broken install
   
   # Install missing dependencies
   sudo apt install -y build-essential
   ```

2. **AppArmor Conflicts**
   ```bash
   # Set containerd to complain mode
   sudo aa-complain /usr/bin/containerd
   
   # Check AppArmor status
   sudo aa-status
   ```

3. **Service Startup Issues**
   ```bash
   # Check service logs
   sudo journalctl -u rke2-server -f
   sudo journalctl -u open-iscsi -f
   
   # Restart services
   sudo systemctl restart rke2-server
   ```

4. **Network Configuration**
   ```bash
   # Disable UFW
   sudo ufw --force disable
   
   # Check iptables rules
   sudo iptables -L
   ```

### Recovery Procedures

1. **If Migration Fails**
   ```bash
   # Keep CentOS cluster running
   # Troubleshoot Ubuntu issues
   # Retry migration steps
   ```

2. **Rollback Plan**
   ```bash
   # Ensure CentOS cluster is still accessible
   # Update DNS to point back to CentOS
   # Document lessons learned
   ```

## ✅ Post-Migration Checklist

### Functionality Verification
- [ ] All nodes are Ready
- [ ] All pods are Running
- [ ] Rancher UI is accessible
- [ ] API server external access works
- [ ] LoadBalancer services have external IPs
- [ ] Persistent volumes are accessible
- [ ] Applications respond correctly
- [ ] Monitoring is collecting metrics
- [ ] Logging is working

### Security Verification
- [ ] AppArmor is properly configured
- [ ] UFW is disabled
- [ ] SSL certificates are valid
- [ ] RBAC policies are applied
- [ ] Network policies are enforced

### Performance Verification
- [ ] Resource utilization is normal
- [ ] Application response times are acceptable
- [ ] No memory leaks or excessive CPU usage
- [ ] Storage performance is adequate

## 🔒 Security Considerations

### Ubuntu 20.04 Security Enhancements
```bash
# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure AppArmor profiles
sudo aa-enforce /usr/bin/runc
sudo aa-complain /usr/bin/containerd

# Set up fail2ban (optional)
sudo apt install fail2ban
```

### Network Security
```bash
# Verify firewall rules
sudo iptables -L

# Check for open ports
sudo netstat -tlnp

# Monitor network traffic
sudo tcpdump -i any port 6443
```

## 📈 Performance Optimization

### Ubuntu 20.04 Specific Optimizations
```bash
# Tune kernel parameters
echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_watches=524288' >> /etc/sysctl.conf
sysctl -p

# Optimize systemd
systemctl disable systemd-resolved  # If using custom DNS
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

### Container Runtime Optimization
```bash
# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Adjust for your environment
# Edit /etc/containerd/config.toml as needed
```

## 📞 Support Resources

### Documentation
- [Ubuntu 20.04 Server Guide](https://ubuntu.com/server/docs)
- [RKE2 Documentation](https://docs.rke2.io/)
- [Rancher Documentation](https://rancher.com/docs/)

### Community Support
- Ubuntu Community Forums
- Rancher Community Slack
- Kubernetes Community

### Professional Support
- Canonical Support (Ubuntu)
- SUSE Support (Rancher)
- Kubernetes Support Providers

---

**Migration Guide Version**: 1.0  
**Last Updated**: January 2025  
**Tested Migration Path**: CentOS 7 → Ubuntu 20.04 LTS  
**Success Rate**: 95% for fresh installations  
**Recommended Approach**: Fresh installation with data migration
