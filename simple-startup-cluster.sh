#!/bin/bash
# Simple RKE2 Cluster Startup Script
# ==================================
# This script simply starts up master node first, then worker nodes
# without complex orchestration or health checks.

set -e

# Configuration
MASTER_NODE="192.168.1.141"
WORKER_NODES=("192.168.1.142" "192.168.1.145")
SSH_USER="partha"
SSH_KEY="~/.ssh/id_rsa"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
}

# Function to check if SSH connection is available
check_ssh() {
    local node=$1
    ssh -i $SSH_KEY -o ConnectTimeout=10 -o StrictHostKeyChecking=no $SSH_USER@$node "echo 'SSH OK'" >/dev/null 2>&1
}

# Function to wait for node to be accessible
wait_for_node() {
    local node=$1
    local timeout=300  # 5 minutes
    local count=0
    
    log "Waiting for $node to be accessible..."
    
    while [ $count -lt $timeout ]; do
        # Check both ping and SSH connectivity
        if ping -c 1 -W 3 $node >/dev/null 2>&1; then
            if check_ssh $node; then
                success "$node is accessible (ping + SSH)"
                return 0
            else
                log "$node responds to ping but SSH not ready yet..."
            fi
        else
            log "$node not responding to ping yet..."
        fi
        
        sleep 10
        count=$((count + 10))
        echo -n "."
    done
    
    echo ""
    error "$node is not accessible within timeout"
    return 1
}

# Function to verify all worker nodes are accessible
verify_all_workers_accessible() {
    log "Verifying all worker nodes are accessible..."
    local all_accessible=true
    
    for worker in "${WORKER_NODES[@]}"; do
        if ! check_ssh $worker; then
            warning "Worker node $worker is not accessible"
            all_accessible=false
        else
            success "Worker node $worker is accessible"
        fi
    done
    
    if [ "$all_accessible" = true ]; then
        success "All worker nodes are accessible"
        return 0
    else
        warning "Some worker nodes are not accessible"
        return 1
    fi
}

# Function to check RKE2 service status
check_rke2_status() {
    local node=$1
    local service_type=$2
    
    log "Checking RKE2 $service_type status on $node..."
    
    if check_ssh $node; then
        local status=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$node "sudo systemctl is-active rke2-$service_type" 2>/dev/null || echo "inactive")
        
        if [ "$status" = "active" ]; then
            success "RKE2 $service_type is running on $node"
            return 0
        else
            log "RKE2 $service_type is $status on $node"
            return 1
        fi
    else
        error "Cannot connect to $node"
        return 1
    fi
}

# Function to get detailed cluster diagnostics
get_cluster_status() {
    log "Getting detailed cluster status and diagnostics..."
    
    if check_ssh $MASTER_NODE; then
        # Wait a bit for services to be ready
        sleep 30
        
        # Check if kubectl works
        local kubectl_result=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_NODE \
            "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml get nodes --no-headers 2>/dev/null | wc -l" 2>/dev/null || echo "0")
        
        if [ "$kubectl_result" -gt 0 ]; then
            success "Cluster is responding - $kubectl_result nodes detected"
            
            # Show detailed node status
            log "=== Node Status ==="
            ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_NODE \
                "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml get nodes -o wide" 2>/dev/null || {
                warning "Could not get detailed node status"
            }
            
            # Check for NotReady nodes
            local not_ready=$(ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_NODE \
                "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml get nodes --no-headers | grep -v Ready | wc -l" 2>/dev/null || echo "0")
            
            if [ "$not_ready" -gt 0 ]; then
                warning "Found $not_ready nodes that are NOT Ready"
                
                # Get detailed status for NotReady nodes
                log "=== NotReady Node Details ==="
                ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_NODE \
                    "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml describe nodes | grep -A 10 -B 5 'Ready.*False'" 2>/dev/null || {
                    warning "Could not get NotReady node details"
                }
                
                # Check system pods status
                log "=== System Pods Status ==="
                ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_NODE \
                    "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml get pods -n kube-system" 2>/dev/null || {
                    warning "Could not get system pods status"
                }
                
                # Check for pending/failed pods
                log "=== Problematic Pods ==="
                ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_NODE \
                    "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml get pods --all-namespaces | grep -E '(Pending|Error|CrashLoopBackOff|Failed)'" 2>/dev/null || {
                    log "No problematic pods found"
                }
            else
                success "All nodes are Ready!"
            fi
            
        else
            warning "Cluster may not be fully ready yet"
        fi
    else
        error "Cannot connect to master node"
    fi
}

# Main startup procedure
main() {
    echo "=============================================="
    echo "🚀 Simple RKE2 Cluster Startup"
    echo "=============================================="
    echo ""
    
    log "Starting simple cluster startup procedure"
    log "Master node: $MASTER_NODE"
    log "Worker nodes: ${WORKER_NODES[*]}"
    echo ""
    
    # Step 1: Check master node accessibility
    log "Step 1: Checking master node accessibility..."
    if ! wait_for_node $MASTER_NODE; then
        error "Master node is not accessible. Please ensure it's powered on."
        exit 1
    fi
    
    # Step 2: Check master node RKE2 status
    log "Step 2: Checking RKE2 server status on master..."
    check_rke2_status $MASTER_NODE "server" || {
        log "RKE2 server not running, it should start automatically on boot"
        log "Waiting for RKE2 server to start..."
        sleep 60
    }
    
    # Step 3: Check worker nodes accessibility
    log "Step 3: Checking worker nodes accessibility..."
    verify_all_workers_accessible
    
    # Step 4: Check RKE2 services on all nodes
    log "Step 4: Checking RKE2 services on all nodes..."
    for worker in "${WORKER_NODES[@]}"; do
        log "Checking worker node: $worker"
        
        if check_ssh $worker; then
            check_rke2_status $worker "agent" || {
                log "RKE2 agent not running on $worker, it should start automatically"
            }
        else
            warning "Worker node $worker is not accessible"
        fi
        
        sleep 5
    done
    
    # Step 5: Basic cluster status check
    log "Step 5: Checking basic cluster status..."
    get_cluster_status
    
    echo ""
    echo "=============================================="
    success "🎉 Simple cluster startup completed!"
    echo "=============================================="
    echo ""
    log "Cluster startup procedure finished"
    log "RKE2 services should start automatically on boot"
    log "It may take a few more minutes for all services to be fully ready"
    echo ""
    echo "💡 Manual checks you can do:"
    echo "  1. Check node status: kubectl get nodes"
    echo "  2. Check pod status: kubectl get pods -A"
    echo "  3. Check service logs: sudo journalctl -u rke2-server -f"
}

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
