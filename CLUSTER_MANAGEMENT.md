# Cluster Management Scripts

This directory contains scripts for safely managing the RKE2 cluster lifecycle, including graceful shutdown and startup procedures.

## Scripts Overview

### Advanced Scripts (Full Orchestration)

#### 🔥 shutdown-cluster.sh
Safely shuts down the RKE2 cluster and physical machines with full orchestration including:
- Graceful workload evacuation
- etcd snapshot creation
- Deployment scaling
- Comprehensive health checks

#### 🚀 startup-cluster.sh  
Starts up the RKE2 cluster after a safe shutdown with full validation and health checks.

### Simple Scripts (Basic Node Management)

#### 🔥 simple-shutdown-cluster.sh
**Simple approach** - Just shuts down nodes in order (workers first, then master) without touching deployments or doing complex orchestration.

#### 🚀 simple-startup-cluster.sh
**Simple approach** - Just checks that nodes are accessible and RKE2 services are running. Relies on automatic service startup.

## Pre-requisites

- SSH access to all cluster nodes with sudo privileges
- SSH key authentication configured
- Cluster nodes accessible at specified IP addresses
- RKE2 installed and configured on all nodes

## Configuration

Both scripts use the following default configuration:

```bash
MASTER_NODE="192.168.1.141"
WORKER_NODES=("192.168.1.142" "192.168.1.145")
SSH_USER="partha"
SSH_KEY="~/.ssh/id_rsa"
KUBECONFIG="/etc/rancher/rke2/rke2.yaml"
KUBECTL="/var/lib/rancher/rke2/bin/kubectl"
```

**Important**: Modify these variables in the scripts if your configuration differs.

## Usage

### Simple Cluster Management (Recommended for Basic Use)

#### Simple Shutdown
```bash
# Just shutdown nodes in order - no deployment changes
./simple-shutdown-cluster.sh
```

**What it does:**
1. **Confirmation**: Asks for confirmation before proceeding
2. **Worker Shutdown**: Shuts down worker nodes first
3. **Master Shutdown**: Shuts down master node last
4. **Wait**: Waits for nodes to power down

**Timeline**: Typically takes 2-3 minutes.

#### Simple Startup
```bash
# Just check nodes are up and RKE2 is running
./simple-startup-cluster.sh
```

**What it does:**
1. **Connectivity Check**: Verifies nodes are accessible
2. **Service Check**: Checks if RKE2 services are running
3. **Basic Status**: Shows basic cluster status
4. **No Orchestration**: Relies on automatic service startup

**Timeline**: Typically takes 3-5 minutes for basic validation.

### Advanced Cluster Management (Full Orchestration)

#### Advanced Shutdown

```bash
# Run the shutdown script
./shutdown-cluster.sh
```

**What it does:**
1. **Health Check**: Verifies cluster accessibility
2. **Graceful Scale Down**: Scales down Rancher and monitoring deployments
3. **etcd Backup**: Creates final etcd snapshot before shutdown
4. **Node Draining**: Gracefully drains worker nodes of workloads
5. **Service Shutdown**: Stops RKE2 services in correct order
6. **Physical Shutdown**: Powers down machines (workers first, then master)

**Timeline**: Typically takes 5-10 minutes depending on workload evacuation.

#### Advanced Startup
```bash
# Full orchestration with health checks  
./startup-cluster.sh
```

**What it does:**
1. **Connectivity Check**: Verifies nodes are accessible
2. **Master Startup**: Starts RKE2 server on master node
3. **API Readiness**: Waits for Kubernetes API to be available
4. **Worker Startup**: Starts RKE2 agents on worker nodes
5. **Node Integration**: Ensures all nodes join the cluster
6. **Health Validation**: Performs comprehensive cluster health check

**Timeline**: Typically takes 10-15 minutes for full cluster readiness.

## Safety Features

### Simple Scripts Safety
- ✅ Confirmation prompt before proceeding
- ✅ Proper shutdown order (workers first, master last)
- ✅ SSH connectivity validation
- ✅ Basic timeout protection
- ✅ No deployment modifications
- ✅ Relies on RKE2 automatic startup

### Advanced Scripts Safety
- ✅ Confirmation prompt before proceeding
- ✅ Graceful workload evacuation (300s timeout)
- ✅ Automatic etcd snapshot creation
- ✅ Proper service shutdown order
- ✅ SSH connectivity validation
- ✅ Timeout protection for all operations

### Advanced Scripts Safety
- ✅ Confirmation prompt before proceeding
- ✅ Graceful workload evacuation (300s timeout)
- ✅ Automatic etcd snapshot creation
- ✅ Proper service shutdown order
- ✅ SSH connectivity validation
- ✅ Timeout protection for all operations

### Advanced Startup Script Safety
- ✅ Step-by-step validation
- ✅ Kubernetes API readiness checks
- ✅ Service health verification
- ✅ Automatic node uncordoning
- ✅ Comprehensive health reporting
- ✅ Timeout protection for startup operations

## Monitoring and Logs

Both scripts provide detailed logging with:
- 🔵 **INFO**: Normal operation messages
- 🟡 **WARNING**: Non-critical issues that can be ignored
- 🔴 **ERROR**: Critical issues requiring attention
- 🟢 **SUCCESS**: Successful operation completion

### Log Example
```
[2025-07-16 10:30:15] Starting safe shutdown procedure for RKE2 cluster
[2025-07-16 10:30:20] SUCCESS: etcd snapshot created: shutdown-20250716-103015
[2025-07-16 10:30:45] SUCCESS: Node worker-1 drained successfully
[2025-07-16 10:31:00] SUCCESS: RKE2 agent stopped on 192.168.1.142
```

## Recovery and Troubleshooting

### If Shutdown Fails
1. **Check SSH connectivity**: Ensure all nodes are accessible
2. **Manual intervention**: May need to manually stop services or power down
3. **Partial shutdown**: Script continues even if some steps fail
4. **etcd backup**: Always created before shutdown attempts

### If Startup Fails
1. **Check power status**: Ensure all machines are powered on
2. **Network connectivity**: Verify nodes can reach each other
3. **Service logs**: Check systemd logs for RKE2 services
4. **Manual restart**: May need to manually restart RKE2 services

### Useful Troubleshooting Commands

```bash
# Check RKE2 service status on a node
sudo systemctl status rke2-server  # On master
sudo systemctl status rke2-agent   # On worker

# View RKE2 logs
sudo journalctl -u rke2-server -f  # On master
sudo journalctl -u rke2-agent -f   # On worker

# Check cluster status manually
sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml get nodes

# List etcd snapshots
sudo ls -la /var/lib/rancher/rke2/server/db/snapshots/
```

## etcd Snapshots

The shutdown script automatically creates etcd snapshots with naming convention:
```
shutdown-YYYYMMDD-HHMMSS
```

### Snapshot Location
```bash
/var/lib/rancher/rke2/server/db/snapshots/
```

### Manual Snapshot Creation
```bash
sudo /var/lib/rancher/rke2/bin/rke2 etcd-snapshot save --name manual-backup-$(date +%Y%m%d-%H%M%S)
```

### Restore from Snapshot
```bash
# Stop RKE2 server
sudo systemctl stop rke2-server

# Restore from snapshot
sudo /var/lib/rancher/rke2/bin/rke2 etcd-snapshot restore --name snapshot-name

# Start RKE2 server
sudo systemctl start rke2-server
```

## Best Practices

### Scheduled Shutdowns
- ✅ Plan shutdowns during maintenance windows
- ✅ Notify users of planned downtime
- ✅ Ensure adequate time for graceful evacuation
- ✅ Test shutdown/startup procedures in non-production

### Regular Maintenance
- ✅ Test scripts monthly in non-production environments
- ✅ Verify SSH key access regularly
- ✅ Monitor etcd snapshot creation
- ✅ Document any configuration changes

### Emergency Procedures
- ✅ Keep scripts updated with cluster changes
- ✅ Maintain offline copies of recovery procedures
- ✅ Have manual shutdown procedures as backup
- ✅ Know how to access physical machines directly

## Integration with Infrastructure

These scripts integrate with the existing RKE2 infrastructure:

- **Ansible Integration**: Can be called from Ansible playbooks
- **Monitoring**: Shutdown/startup events should be monitored
- **Backup Strategy**: Works with existing etcd backup procedures
- **Security**: Follows established SSH key and access patterns

## Customization

To adapt these scripts for different environments:

1. **Update node configuration** in script variables
2. **Modify SSH settings** for different authentication methods
3. **Adjust timeouts** based on workload characteristics
4. **Add custom health checks** for specific applications
5. **Integrate with monitoring systems** for alerting

## Version History

- **v1.0** (2025-07-16): Initial release with basic shutdown/startup functionality
- Supports RKE2 cluster with master + 2 workers
- Includes etcd snapshot creation and health validation
- Comprehensive logging and error handling

---

**⚠️ Important Notes:**
- Always test in non-production environments first
- Ensure you have physical access to machines in case of issues
- Keep these scripts updated as cluster configuration changes
- Monitor logs during shutdown/startup procedures for any issues
