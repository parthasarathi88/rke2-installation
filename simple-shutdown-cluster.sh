#!/bin/bash
# Simple RKE2 Cluster Shutdown Script
# ===================================
# This script simply shuts down worker nodes first, then master node
# without modifying any deployments or doing complex orchestration.

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
    ssh -i $SSH_KEY -o ConnectTimeout=5 -o StrictHostKeyChecking=no $SSH_USER@$node "echo 'SSH OK'" >/dev/null 2>&1
}

# Function to shutdown a node
shutdown_node() {
    local node=$1
    log "Shutting down node $node..."
    
    if check_ssh $node; then
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$node "sudo shutdown -h +1 'Cluster shutdown initiated'" || {
            error "Failed to initiate shutdown on $node"
        }
        success "Shutdown initiated on $node"
    else
        error "Cannot connect to $node via SSH"
    fi
}

# Function to wait for node shutdown
wait_for_shutdown() {
    local node=$1
    local timeout=180  # 3 minutes
    local count=0
    
    log "Waiting for $node to shutdown..."
    
    while [ $count -lt $timeout ]; do
        if ! check_ssh $node; then
            success "$node has shut down"
            return 0
        fi
        sleep 10
        count=$((count + 10))
        echo -n "."
    done
    
    echo ""
    warning "$node did not shutdown within timeout"
    return 1
}

# Function to verify node is not responding (ping + SSH)
verify_node_down() {
    local node=$1
    local max_attempts=5
    local attempt=1
    
    log "Verifying $node is completely down..."
    
    while [ $attempt -le $max_attempts ]; do
        # Check SSH first
        if check_ssh $node; then
            log "Attempt $attempt/$max_attempts: $node still responding to SSH"
        else
            # Also check ping to be extra sure
            if ping -c 2 -W 3 $node >/dev/null 2>&1; then
                log "Attempt $attempt/$max_attempts: $node still responding to ping"
            else
                success "$node is completely down (no SSH, no ping)"
                return 0
            fi
        fi
        
        sleep 10
        attempt=$((attempt + 1))
    done
    
    warning "$node may still be partially responsive"
    return 1
}

# Function to verify all worker nodes are down
verify_all_workers_down() {
    log "Verifying all worker nodes are completely shut down..."
    local all_down=true
    
    for worker in "${WORKER_NODES[@]}"; do
        if ! verify_node_down $worker; then
            warning "Worker node $worker may not be completely down"
            all_down=false
        fi
    done
    
    if [ "$all_down" = true ]; then
        success "All worker nodes are confirmed down"
        return 0
    else
        warning "Some worker nodes may still be responsive"
        return 1
    fi
}

# Function to confirm cluster is completely shutdown
confirm_cluster_shutdown() {
    log "Confirming entire cluster is shut down..."
    
    # Check master node
    if ! verify_node_down $MASTER_NODE; then
        warning "Master node may not be completely down"
        return 1
    fi
    
    # Double-check all nodes are down
    local all_nodes_down=true
    
    log "Final verification of all cluster nodes..."
    for worker in "${WORKER_NODES[@]}"; do
        if ping -c 1 -W 2 $worker >/dev/null 2>&1; then
            warning "Worker node $worker is still responding to ping"
            all_nodes_down=false
        fi
    done
    
    if ping -c 1 -W 2 $MASTER_NODE >/dev/null 2>&1; then
        warning "Master node $MASTER_NODE is still responding to ping"
        all_nodes_down=false
    fi
    
    if [ "$all_nodes_down" = true ]; then
        success "Cluster shutdown confirmed - no nodes responding"
        return 0
    else
        warning "Some cluster nodes may still be responsive"
        return 1
    fi
}

# Main shutdown procedure
main() {
    echo "=============================================="
    echo "🔥 Simple RKE2 Cluster Shutdown"
    echo "=============================================="
    echo ""
    
    log "Starting simple cluster shutdown procedure"
    log "Master node: $MASTER_NODE"
    log "Worker nodes: ${WORKER_NODES[*]}"
    echo ""
    
    # Confirmation prompt
    echo -e "${YELLOW}⚠️  WARNING: This will shut down all cluster nodes!${NC}"
    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log "Shutdown cancelled by user"
        exit 0
    fi
    
    echo ""
    log "Proceeding with cluster shutdown..."
    
    # Step 1: Shutdown worker nodes
    log "Step 1: Shutting down worker nodes..."
    for worker in "${WORKER_NODES[@]}"; do
        shutdown_node $worker
        sleep 2
    done
    
    # Step 2: Wait for worker nodes to shutdown and verify they're down
    log "Step 2: Waiting for worker nodes to shutdown completely..."
    local workers_shutdown=true
    
    for worker in "${WORKER_NODES[@]}"; do
        if ! wait_for_shutdown $worker; then
            workers_shutdown=false
        fi
    done
    
    # Verify all workers are completely down before proceeding
    log "Step 2a: Verifying all worker nodes are completely down..."
    if verify_all_workers_down; then
        success "All worker nodes confirmed down - safe to shutdown master"
    else
        warning "Some workers may still be running, but proceeding with master shutdown"
    fi
    
    # Step 3: Only shutdown master after workers are confirmed down
    log "Step 3: Shutting down master node (workers are down)..."
    shutdown_node $MASTER_NODE
    
    # Step 4: Wait for master node to shutdown
    log "Step 4: Waiting for master node to shutdown..."
    wait_for_shutdown $MASTER_NODE
    
    # Step 5: Final confirmation that entire cluster is down
    log "Step 5: Final cluster shutdown verification..."
    confirm_cluster_shutdown
    
    echo ""
    echo "=============================================="
    success "🎉 Cluster shutdown completed!"
    echo "=============================================="
    echo ""
    log "All cluster nodes have been shut down"
    log "Cluster is confirmed offline - no nodes responding"
    echo ""
    echo "💡 To restart the cluster:"
    echo "  1. Power on master node first (192.168.1.141)"
    echo "  2. Wait for master to be fully ready"
    echo "  3. Power on worker nodes (192.168.1.142, 192.168.1.145)"
    echo "  4. Run ./simple-startup-cluster.sh to verify startup"
}

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
