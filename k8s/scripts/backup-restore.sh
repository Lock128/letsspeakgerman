#!/bin/bash

# Redis Backup and Restore Script for Kubernetes
# This script handles backup and restore operations for Redis data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="dev"
OPERATION=""
BACKUP_FILE=""
BACKUP_DIR="./backups"
REDIS_POD=""
COMPRESS=true
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS] OPERATION"
    echo ""
    echo "Backup and restore Redis data in Kubernetes"
    echo ""
    echo "Operations:"
    echo "  backup                      Create backup of Redis data"
    echo "  restore                     Restore Redis data from backup"
    echo "  list                        List available backups"
    echo "  cleanup                     Clean up old backups"
    echo "  status                      Show Redis status and info"
    echo ""
    echo "Options:"
    echo "  -n, --namespace NAMESPACE   Kubernetes namespace (default: dev)"
    echo "  -f, --file FILE            Backup file path (for restore operation)"
    echo "  -d, --dir DIRECTORY        Backup directory (default: ./backups)"
    echo "  -p, --pod POD              Specific Redis pod name (auto-detected if not specified)"
    echo "  --no-compress              Don't compress backup files"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 backup                           # Create backup in default location"
    echo "  $0 backup -d /path/to/backups      # Create backup in specific directory"
    echo "  $0 restore -f backup_20231201.rdb  # Restore from specific backup file"
    echo "  $0 list -d /path/to/backups        # List backups in specific directory"
    echo "  $0 cleanup -d ./backups            # Clean up old backups"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -f|--file)
            BACKUP_FILE="$2"
            shift 2
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -p|--pod)
            REDIS_POD="$2"
            shift 2
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        backup|restore|list|cleanup|status)
            OPERATION="$1"
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate operation
if [ -z "$OPERATION" ]; then
    print_error "Operation is required"
    usage
fi

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_error "Namespace '$NAMESPACE' does not exist"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Find Redis pod
find_redis_pod() {
    local kubectl_opts="--namespace=$NAMESPACE"
    
    if [ -n "$REDIS_POD" ]; then
        # Verify specified pod exists
        if kubectl get pod "$REDIS_POD" $kubectl_opts &> /dev/null; then
            echo "$REDIS_POD"
        else
            print_error "Specified Redis pod '$REDIS_POD' not found"
            exit 1
        fi
    else
        # Auto-detect Redis pod
        local redis_pods=$(kubectl get pods -l app=redis $kubectl_opts -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        
        if [ -z "$redis_pods" ]; then
            # Try alternative labels
            redis_pods=$(kubectl get pods $kubectl_opts -o jsonpath='{.items[?(@.spec.containers[0].image=~"redis")].metadata.name}' 2>/dev/null)
        fi
        
        if [ -z "$redis_pods" ]; then
            print_error "No Redis pods found in namespace '$NAMESPACE'"
            print_status "Available pods:"
            kubectl get pods $kubectl_opts
            exit 1
        fi
        
        # Use first Redis pod found
        echo $redis_pods | awk '{print $1}'
    fi
}

# Create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        print_status "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
}

# Backup Redis data
backup_redis() {
    print_status "Creating Redis backup..."
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local redis_pod=$(find_redis_pod)
    
    print_status "Using Redis pod: $redis_pod"
    
    create_backup_dir
    
    # Generate backup filename
    local backup_name="redis_backup_${TIMESTAMP}"
    local backup_path="$BACKUP_DIR/${backup_name}.rdb"
    
    if [ "$COMPRESS" = true ]; then
        backup_path="${backup_path}.gz"
    fi
    
    print_status "Creating backup: $backup_path"
    
    # Force Redis to save current state
    print_status "Forcing Redis BGSAVE..."
    kubectl exec "$redis_pod" $kubectl_opts -- redis-cli BGSAVE
    
    # Wait for background save to complete
    print_status "Waiting for background save to complete..."
    while true; do
        local save_status=$(kubectl exec "$redis_pod" $kubectl_opts -- redis-cli LASTSAVE 2>/dev/null)
        sleep 2
        local new_save_status=$(kubectl exec "$redis_pod" $kubectl_opts -- redis-cli LASTSAVE 2>/dev/null)
        
        if [ "$save_status" != "$new_save_status" ]; then
            print_debug "Background save completed"
            break
        fi
        
        print_debug "Waiting for background save..."
        sleep 3
    done
    
    # Copy RDB file from pod
    print_status "Copying RDB file from pod..."
    
    if [ "$COMPRESS" = true ]; then
        kubectl exec "$redis_pod" $kubectl_opts -- cat /data/dump.rdb | gzip > "$backup_path"
    else
        kubectl cp "$NAMESPACE/$redis_pod:/data/dump.rdb" "$backup_path"
    fi
    
    # Verify backup file
    if [ -f "$backup_path" ] && [ -s "$backup_path" ]; then
        local file_size=$(ls -lh "$backup_path" | awk '{print $5}')
        print_success "Backup created successfully: $backup_path ($file_size)"
        
        # Create metadata file
        local metadata_file="${backup_path}.meta"
        cat > "$metadata_file" << EOF
Backup Metadata
===============
Timestamp: $(date)
Namespace: $NAMESPACE
Redis Pod: $redis_pod
Backup File: $backup_path
Compressed: $COMPRESS
Redis Version: $(kubectl exec "$redis_pod" $kubectl_opts -- redis-cli INFO server | grep redis_version | cut -d: -f2 | tr -d '\r')
Database Size: $(kubectl exec "$redis_pod" $kubectl_opts -- redis-cli DBSIZE)
EOF
        
        print_status "Metadata saved: $metadata_file"
    else
        print_error "Backup failed - file not created or empty"
        exit 1
    fi
}

# Restore Redis data
restore_redis() {
    if [ -z "$BACKUP_FILE" ]; then
        print_error "Backup file is required for restore operation. Use -f flag."
        exit 1
    fi
    
    if [ ! -f "$BACKUP_FILE" ]; then
        print_error "Backup file not found: $BACKUP_FILE"
        exit 1
    fi
    
    print_status "Restoring Redis data from: $BACKUP_FILE"
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local redis_pod=$(find_redis_pod)
    
    print_status "Using Redis pod: $redis_pod"
    
    # Confirm restore operation
    echo ""
    print_warning "This will replace all current Redis data!"
    print_warning "Current database size: $(kubectl exec "$redis_pod" $kubectl_opts -- redis-cli DBSIZE) keys"
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_status "Restore cancelled by user"
        exit 0
    fi
    
    # Stop Redis temporarily for restore
    print_status "Stopping Redis for restore..."
    kubectl exec "$redis_pod" $kubectl_opts -- redis-cli SHUTDOWN NOSAVE || true
    
    # Wait for Redis to stop
    sleep 5
    
    # Copy backup file to pod
    print_status "Copying backup file to pod..."
    
    if [[ "$BACKUP_FILE" == *.gz ]]; then
        # Decompress and copy
        gunzip -c "$BACKUP_FILE" | kubectl exec -i "$redis_pod" $kubectl_opts -- tee /data/dump.rdb > /dev/null
    else
        # Copy directly
        kubectl cp "$BACKUP_FILE" "$NAMESPACE/$redis_pod:/data/dump.rdb"
    fi
    
    # Restart Redis
    print_status "Restarting Redis..."
    kubectl delete pod "$redis_pod" $kubectl_opts
    
    # Wait for new pod to be ready
    print_status "Waiting for Redis pod to be ready..."
    kubectl wait --for=condition=ready pod -l app=redis $kubectl_opts --timeout=120s
    
    # Verify restore
    local new_redis_pod=$(find_redis_pod)
    local restored_keys=$(kubectl exec "$new_redis_pod" $kubectl_opts -- redis-cli DBSIZE)
    
    print_success "Restore completed successfully!"
    print_status "Restored database contains $restored_keys keys"
}

# List available backups
list_backups() {
    print_status "Available backups in: $BACKUP_DIR"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "Backup directory does not exist: $BACKUP_DIR"
        return
    fi
    
    local backups=$(find "$BACKUP_DIR" -name "redis_backup_*.rdb*" -type f | sort -r)
    
    if [ -z "$backups" ]; then
        print_warning "No backup files found"
        return
    fi
    
    echo ""
    printf "%-30s %-10s %-20s %s\n" "Backup File" "Size" "Date" "Compressed"
    printf "%-30s %-10s %-20s %s\n" "----------" "----" "----" "----------"
    
    for backup in $backups; do
        local filename=$(basename "$backup")
        local size=$(ls -lh "$backup" | awk '{print $5}')
        local date=$(ls -l "$backup" | awk '{print $6, $7, $8}')
        local compressed="No"
        
        if [[ "$backup" == *.gz ]]; then
            compressed="Yes"
        fi
        
        printf "%-30s %-10s %-20s %s\n" "$filename" "$size" "$date" "$compressed"
        
        # Show metadata if available
        local metadata_file="${backup}.meta"
        if [ -f "$metadata_file" ]; then
            local db_size=$(grep "Database Size:" "$metadata_file" | cut -d: -f2 | tr -d ' ')
            if [ -n "$db_size" ]; then
                printf "  └─ Database size: %s keys\n" "$db_size"
            fi
        fi
    done
}

# Clean up old backups
cleanup_backups() {
    print_status "Cleaning up old backups..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_warning "Backup directory does not exist: $BACKUP_DIR"
        return
    fi
    
    # Keep last 10 backups, delete older ones
    local backups=$(find "$BACKUP_DIR" -name "redis_backup_*.rdb*" -type f | sort -r)
    local backup_count=$(echo "$backups" | wc -l)
    
    if [ "$backup_count" -le 10 ]; then
        print_status "Found $backup_count backups, no cleanup needed (keeping up to 10)"
        return
    fi
    
    local to_delete=$(echo "$backups" | tail -n +11)
    local delete_count=$(echo "$to_delete" | wc -l)
    
    print_status "Found $backup_count backups, deleting $delete_count old backups..."
    
    for backup in $to_delete; do
        print_debug "Deleting: $(basename "$backup")"
        rm -f "$backup"
        
        # Also delete metadata file if it exists
        local metadata_file="${backup}.meta"
        if [ -f "$metadata_file" ]; then
            rm -f "$metadata_file"
        fi
    done
    
    print_success "Cleanup completed - deleted $delete_count old backups"
}

# Show Redis status
show_status() {
    print_status "Redis Status"
    
    local kubectl_opts="--namespace=$NAMESPACE"
    local redis_pod=$(find_redis_pod)
    
    print_status "Using Redis pod: $redis_pod"
    
    echo ""
    print_status "Pod Status:"
    kubectl get pod "$redis_pod" $kubectl_opts
    
    echo ""
    print_status "Redis Info:"
    kubectl exec "$redis_pod" $kubectl_opts -- redis-cli INFO server | head -15
    
    echo ""
    print_status "Database Info:"
    kubectl exec "$redis_pod" $kubectl_opts -- redis-cli INFO keyspace
    
    echo ""
    print_status "Memory Usage:"
    kubectl exec "$redis_pod" $kubectl_opts -- redis-cli INFO memory | grep used_memory
    
    echo ""
    print_status "Connection Info:"
    kubectl exec "$redis_pod" $kubectl_opts -- redis-cli INFO clients
    
    echo ""
    print_status "Persistence Info:"
    kubectl exec "$redis_pod" $kubectl_opts -- redis-cli INFO persistence
    
    # Test connectivity
    echo ""
    print_status "Connectivity Test:"
    if kubectl exec "$redis_pod" $kubectl_opts -- redis-cli ping | grep -q "PONG"; then
        print_success "✓ Redis is responding to ping"
    else
        print_error "✗ Redis is not responding to ping"
    fi
    
    # Show database size
    local db_size=$(kubectl exec "$redis_pod" $kubectl_opts -- redis-cli DBSIZE)
    print_status "Database contains $db_size keys"
}

# Main execution
main() {
    print_status "Starting Redis backup/restore operation: $OPERATION"
    print_status "Configuration:"
    print_status "  Namespace: $NAMESPACE"
    print_status "  Backup Directory: $BACKUP_DIR"
    if [ -n "$BACKUP_FILE" ]; then
        print_status "  Backup File: $BACKUP_FILE"
    fi
    if [ -n "$REDIS_POD" ]; then
        print_status "  Redis Pod: $REDIS_POD"
    fi
    print_status "  Compress: $COMPRESS"
    
    check_prerequisites
    
    case $OPERATION in
        backup)
            backup_redis
            ;;
        restore)
            restore_redis
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_backups
            ;;
        status)
            show_status
            ;;
        *)
            print_error "Unknown operation: $OPERATION"
            usage
            ;;
    esac
    
    print_success "Operation completed!"
}

# Run main function
main "$@"