# RKE2 + Rancher Installation for Ubuntu 20.04 LTS

This project has been updated to support Ubuntu 20.04 LTS deployments with the following enhancements:

## Key Changes for Ubuntu 20.04

### 1. Package Management
- **Replaced**: `yum` with `apt` package manager
- **Added**: Ubuntu-specific packages like `open-iscsi`, `multipath-tools`, `apparmor-utils`
- **Updated**: Package names to match Ubuntu repositories

### 2. Security Framework
- **AppArmor**: Configured AppArmor instead of SELinux for container security
- **UFW**: Replaced `firewalld` with UFW (Uncomplicated Firewall) management
- **Compatibility**: Ensured containerd works with AppArmor profiles

### 3. Service Management
- **iSCSI Services**: Updated for Ubuntu's `open-iscsi` service structure
- **Service Names**: Adapted service names for Ubuntu/Debian family
- **Systemd Units**: Verified compatibility with Ubuntu 20.04 systemd

### 4. Version Updates
- **RKE2**: Updated to `v1.28.15+rke2r1` for better Ubuntu 20.04 support
- **Rancher**: Updated to `2.10.3` for Kubernetes 1.28 compatibility
- **Components**: All stack components updated for latest Ubuntu LTS support

## Prerequisites for Ubuntu 20.04

### System Requirements
```bash
# Ubuntu 20.04 LTS (Focal Fossa)
lsb_release -a

# Minimum hardware requirements
- CPU: 2 cores (4 recommended for master)
- RAM: 4GB (6GB recommended for workers with monitoring)
- Storage: 20GB+ available disk space
- Network: Static IP addresses recommended
```

### Package Dependencies
The following packages will be automatically installed:
- `curl`, `wget`, `tar` - Basic utilities
- `iptables` - Network filtering
- `nfs-common` - NFS client support
- `open-iscsi` - iSCSI initiator
- `multipath-tools` - Device mapper multipath
- `python3-pip` - Python package manager
- `apparmor-utils` - AppArmor utilities

### Network Configuration
Ensure your Ubuntu 20.04 nodes have:
- Static IP addresses configured
- DNS resolution working
- SSH access with key-based authentication
- Internet connectivity for package downloads

## Installation Instructions

### 1. Prepare Inventory File
Update the inventory file with your Ubuntu 20.04 node details:

```ini
[rke2_nodes]
mgmt01 ansible_host=192.168.1.141 ansible_user=ubuntu node_role=server
worker01 ansible_host=192.168.1.142 ansible_user=ubuntu node_role=agent
worker02 ansible_host=192.168.1.145 ansible_user=ubuntu node_role=agent
```

### 2. Configure SSH Access
Ensure passwordless SSH access to all nodes:

```bash
# Generate SSH key if not exists
ssh-keygen -t rsa -b 4096

# Copy to all nodes
ssh-copy-id ubuntu@192.168.1.141
ssh-copy-id ubuntu@192.168.1.142
ssh-copy-id ubuntu@192.168.1.145
```

### 3. Run Installation
Execute the complete installation playbook:

```bash
# Run the complete installation
ansible-playbook -i inventory complete-installation-runbook.yml

# Or run specific components
ansible-playbook -i inventory complete-installation-runbook.yml --tags prerequisites
ansible-playbook -i inventory complete-installation-runbook.yml --tags rke2
ansible-playbook -i inventory complete-installation-runbook.yml --tags networking
```

## Ubuntu 20.04 Specific Configurations

### AppArmor Configuration
The playbook automatically configures AppArmor for container compatibility:

```bash
# AppArmor profiles are set to complain mode for containerd
aa-complain /usr/bin/containerd

# AppArmor service is disabled during installation
systemctl disable apparmor.service
```

### UFW Firewall Management
Ubuntu's UFW firewall is managed as follows:

```bash
# UFW is disabled to allow RKE2 to manage its own firewall rules
ufw --force disable

# RKE2 will configure iptables rules directly
```

### Service Dependencies
Ubuntu 20.04 specific service configurations:

```yaml
iSCSI Services:
  - iscsid: iSCSI daemon
  - open-iscsi: Ubuntu's iSCSI service
  
Multipath:
  - multipathd: Device mapper multipath daemon
```

## Verification Steps

### 1. Check Prerequisites
```bash
# Verify packages are installed
dpkg -l | grep -E "(open-iscsi|multipath-tools|nfs-common)"

# Check services
systemctl status iscsid
systemctl status open-iscsi
systemctl status multipathd
```

### 2. Verify RKE2 Installation
```bash
# Check RKE2 services
systemctl status rke2-server  # On master node
systemctl status rke2-agent   # On worker nodes

# Verify cluster
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get nodes
```

### 3. Check AppArmor Status
```bash
# Verify AppArmor configuration
aa-status
aa-complain /usr/bin/containerd
```

## Troubleshooting Ubuntu 20.04 Specific Issues

### AppArmor Conflicts
If you encounter AppArmor-related container issues:

```bash
# Set containerd to complain mode
sudo aa-complain /usr/bin/containerd

# Or disable AppArmor entirely (not recommended for production)
sudo systemctl disable apparmor.service
sudo systemctl stop apparmor.service
```

### Package Installation Issues
If package installation fails:

```bash
# Update package cache
sudo apt update

# Install packages manually
sudo apt install open-iscsi multipath-tools nfs-common

# Fix broken packages
sudo apt --fix-broken install
```

### Service Startup Issues
If services fail to start:

```bash
# Check service logs
sudo journalctl -u iscsid
sudo journalctl -u open-iscsi
sudo journalctl -u rke2-server

# Restart services
sudo systemctl restart iscsid
sudo systemctl restart open-iscsi
```

### Network Configuration
If network connectivity issues occur:

```bash
# Check UFW status
sudo ufw status

# Ensure UFW is disabled
sudo ufw --force disable

# Verify iptables rules
sudo iptables -L
```

## Post-Installation Configuration

### 1. Access Rancher UI
```bash
# Get bootstrap password
sudo kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'

# Access via browser
https://rancher.dellpc.in
```

### 2. Configure kubectl Access
```bash
# Copy kubeconfig to local machine
scp ubuntu@192.168.1.141:/etc/rancher/rke2/rke2.yaml ~/.kube/config

# Update server address in kubeconfig
sed -i 's/127.0.0.1/192.168.1.200/g' ~/.kube/config
```

### 3. Verify External Access
```bash
# Test external API access
kubectl --server=https://192.168.1.200:6443 get nodes

# Test LoadBalancer services
kubectl get svc --all-namespaces | grep LoadBalancer
```

## Monitoring and Maintenance

### Regular Maintenance Tasks
```bash
# Update packages
sudo apt update && sudo apt upgrade

# Check service health
systemctl status rke2-server rke2-agent iscsid open-iscsi multipathd

# Monitor cluster health
kubectl get nodes
kubectl get pods --all-namespaces
```

### Log Locations
```bash
# RKE2 logs
sudo journalctl -u rke2-server -f
sudo journalctl -u rke2-agent -f

# System logs
/var/log/syslog
/var/log/kern.log

# Container logs
sudo crictl logs <container-id>
```

## Migration Notes

If migrating from CentOS/RHEL to Ubuntu 20.04:

1. **Backup Data**: Ensure etcd snapshots and persistent volume data are backed up
2. **DNS Configuration**: Update DNS entries to point to new Ubuntu nodes
3. **SSL Certificates**: Regenerate certificates with new node IP addresses
4. **Monitoring**: Update monitoring configurations for Ubuntu-specific metrics
5. **Testing**: Thoroughly test all applications and services after migration

## Support and Resources

- **Ubuntu 20.04 Documentation**: https://ubuntu.com/server/docs
- **RKE2 Documentation**: https://docs.rke2.io/
- **Rancher Documentation**: https://rancher.com/docs/
- **Kubernetes Documentation**: https://kubernetes.io/docs/

---

**Version**: 2.1.0 (Ubuntu 20.04 LTS)  
**Last Updated**: January 2025  
**Tested On**: Ubuntu 20.04.6 LTS (Focal Fossa)  
**Compatible RKE2**: v1.28.15+rke2r1  
**Compatible Rancher**: 2.10.3
