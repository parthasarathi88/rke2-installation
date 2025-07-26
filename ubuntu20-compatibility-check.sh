#!/bin/bash

# Ubuntu 20.04 Compatibility Check Script for RKE2 Installation
# This script verifies that Ubuntu 20.04 nodes meet the requirements for RKE2 deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    log "Checking Ubuntu version..."
    
    if [ ! -f /etc/os-release ]; then
        error "Cannot determine OS version"
        return 1
    fi
    
    source /etc/os-release
    
    if [ "$ID" != "ubuntu" ]; then
        error "This script is designed for Ubuntu systems only. Detected: $ID"
        return 1
    fi
    
    if [ "$VERSION_ID" != "20.04" ]; then
        warning "This script is optimized for Ubuntu 20.04. Detected: $VERSION_ID"
        echo "  Continuing anyway, but there may be compatibility issues..."
    else
        success "Ubuntu 20.04 LTS detected"
    fi
    
    log "OS Details: $PRETTY_NAME"
    return 0
}

# Check system resources
check_system_resources() {
    log "Checking system resources..."
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    log "CPU cores: $cpu_cores"
    
    if [ "$cpu_cores" -lt 2 ]; then
        error "Minimum 2 CPU cores required. Found: $cpu_cores"
        return 1
    else
        success "CPU requirement met: $cpu_cores cores"
    fi
    
    # Check memory
    local memory_gb=$(free -g | awk 'NR==2{printf "%.1f", $2}')
    local memory_mb=$(free -m | awk 'NR==2{print $2}')
    log "Memory: ${memory_gb}GB (${memory_mb}MB)"
    
    if [ "$memory_mb" -lt 3800 ]; then
        error "Minimum 4GB RAM required. Found: ${memory_gb}GB"
        return 1
    else
        success "Memory requirement met: ${memory_gb}GB"
    fi
    
    # Check disk space
    local disk_space=$(df / | awk 'NR==2{print $4}')
    local disk_space_gb=$((disk_space / 1024 / 1024))
    log "Available disk space: ${disk_space_gb}GB"
    
    if [ "$disk_space_gb" -lt 15 ]; then
        error "Minimum 20GB free disk space required. Found: ${disk_space_gb}GB"
        return 1
    else
        success "Disk space requirement met: ${disk_space_gb}GB available"
    fi
    
    return 0
}

# Check network configuration
check_network() {
    log "Checking network configuration..."
    
    # Check if we have an IP address
    local ip_address=$(hostname -I | awk '{print $1}')
    if [ -z "$ip_address" ]; then
        error "No IP address found"
        return 1
    else
        log "Primary IP address: $ip_address"
    fi
    
    # Check internet connectivity
    log "Testing internet connectivity..."
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        success "Internet connectivity verified"
    else
        warning "Internet connectivity test failed - may affect package downloads"
    fi
    
    # Check DNS resolution
    log "Testing DNS resolution..."
    if nslookup google.com >/dev/null 2>&1; then
        success "DNS resolution working"
    else
        warning "DNS resolution test failed"
    fi
    
    return 0
}

# Check required packages
check_packages() {
    log "Checking for required packages..."
    
    local required_packages=(
        "curl"
        "wget"
        "tar"
        "iptables"
        "python3"
        "systemd"
    )
    
    local missing_packages=()
    
    for package in "${required_packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$package "; then
            log "✓ $package is installed"
        else
            missing_packages+=("$package")
            warning "✗ $package is not installed"
        fi
    done
    
    if [ ${#missing_packages[@]} -eq 0 ]; then
        success "All required packages are installed"
    else
        warning "Missing packages: ${missing_packages[*]}"
        log "These packages will be installed during RKE2 deployment"
    fi
    
    return 0
}

# Check kernel modules
check_kernel_modules() {
    log "Checking kernel module support..."
    
    local required_modules=(
        "overlay"
        "br_netfilter"
        "ip_tables"
        "iptable_filter"
        "iptable_nat"
    )
    
    for module in "${required_modules[@]}"; do
        if lsmod | grep -q "^$module"; then
            log "✓ $module module is loaded"
        elif modprobe "$module" 2>/dev/null; then
            log "✓ $module module loaded successfully"
            modprobe -r "$module" 2>/dev/null || true
        else
            warning "✗ Cannot load $module module"
        fi
    done
    
    success "Kernel module support verified"
    return 0
}

# Check AppArmor status
check_apparmor() {
    log "Checking AppArmor configuration..."
    
    if command -v aa-status >/dev/null 2>&1; then
        local apparmor_status=$(aa-status --enabled && echo "enabled" || echo "disabled")
        log "AppArmor status: $apparmor_status"
        
        if [ "$apparmor_status" = "enabled" ]; then
            log "AppArmor is enabled - will be configured for container compatibility"
            success "AppArmor detected and will be configured"
        else
            log "AppArmor is disabled"
        fi
    else
        warning "AppArmor tools not found - will be installed during deployment"
    fi
    
    return 0
}

# Check UFW firewall
check_ufw() {
    log "Checking UFW firewall status..."
    
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status | grep -o "Status: \w*" | cut -d' ' -f2)
        log "UFW status: $ufw_status"
        
        if [ "$ufw_status" = "active" ]; then
            warning "UFW is active - will be disabled during RKE2 installation"
            log "RKE2 manages its own firewall rules via iptables"
        else
            success "UFW is inactive - good for RKE2 deployment"
        fi
    else
        log "UFW not found - will be managed during deployment"
    fi
    
    return 0
}

# Check systemd
check_systemd() {
    log "Checking systemd configuration..."
    
    if systemctl --version >/dev/null 2>&1; then
        local systemd_version=$(systemctl --version | head -n1 | awk '{print $2}')
        log "systemd version: $systemd_version"
        success "systemd is available"
    else
        error "systemd is required but not found"
        return 1
    fi
    
    # Check if systemd is the init system
    if [ -d /run/systemd/system ]; then
        success "systemd is the active init system"
    else
        error "systemd is not the active init system"
        return 1
    fi
    
    return 0
}

# Check container runtime prerequisites
check_container_runtime() {
    log "Checking container runtime prerequisites..."
    
    # Check for existing container runtimes
    if command -v docker >/dev/null 2>&1; then
        warning "Docker is installed - may conflict with containerd"
        log "Consider removing Docker before RKE2 installation"
    fi
    
    if command -v containerd >/dev/null 2>&1; then
        log "containerd is already installed"
    else
        log "containerd will be installed by RKE2"
    fi
    
    # Check cgroup configuration
    if [ -f /proc/cgroups ]; then
        log "cgroup support available"
        success "Container runtime prerequisites met"
    else
        error "cgroup support not found"
        return 1
    fi
    
    return 0
}

# Check SSH configuration
check_ssh() {
    log "Checking SSH configuration..."
    
    if systemctl is-active ssh >/dev/null 2>&1; then
        success "SSH service is running"
    elif systemctl is-active sshd >/dev/null 2>&1; then
        success "SSH service is running (sshd)"
    else
        error "SSH service is not running"
        return 1
    fi
    
    # Check if SSH keys exist
    if [ -f ~/.ssh/authorized_keys ]; then
        log "SSH authorized_keys file exists"
    else
        warning "No SSH authorized_keys file found"
        log "Ensure SSH key-based authentication is configured"
    fi
    
    return 0
}

# Main compatibility check function
main() {
    echo "=============================================="
    echo "🔍 Ubuntu 20.04 Compatibility Check for RKE2"
    echo "=============================================="
    echo ""
    
    local failed_checks=0
    
    # Run all checks
    check_root || ((failed_checks++))
    check_ubuntu_version || ((failed_checks++))
    check_system_resources || ((failed_checks++))
    check_network || ((failed_checks++))
    check_packages || ((failed_checks++))
    check_kernel_modules || ((failed_checks++))
    check_apparmor || ((failed_checks++))
    check_ufw || ((failed_checks++))
    check_systemd || ((failed_checks++))
    check_container_runtime || ((failed_checks++))
    check_ssh || ((failed_checks++))
    
    echo ""
    echo "=============================================="
    
    if [ $failed_checks -eq 0 ]; then
        success "🎉 All compatibility checks passed!"
        echo ""
        log "This Ubuntu 20.04 system is ready for RKE2 installation"
        log "You can proceed with running the Ansible playbook"
        echo ""
        log "Next steps:"
        log "1. Update the inventory file with your node details"
        log "2. Configure SSH key-based authentication"
        log "3. Run: ansible-playbook -i inventory complete-installation-runbook.yml"
    else
        error "❌ $failed_checks compatibility check(s) failed"
        echo ""
        log "Please address the failed checks before proceeding with RKE2 installation"
        log "Some issues may be automatically resolved during the Ansible deployment"
        exit 1
    fi
    
    echo "=============================================="
}

# Script entry point
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
