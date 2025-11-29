#!/bin/bash
# Common functions and utilities for CloudPhoenix scripts
# Source this file in other scripts: source "$(dirname "$0")/lib/common.sh"

set -o errexit  # Exit on error
set -o nounset  # Exit on undefined variable
set -o pipefail # Exit on pipe failure

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    case $level in
        INFO)
            echo -e "${GREEN}[INFO]${NC} [${timestamp}] ${message}" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[WARN]${NC} [${timestamp}] ${message}" >&2
            ;;
        ERROR)
            echo -e "${RED}[ERROR]${NC} [${timestamp}] ${message}" >&2
            ;;
        *)
            echo "[${timestamp}] ${message}" >&2
            ;;
    esac
}

log_info() {
    log INFO "$@"
}

log_warn() {
    log WARN "$@"
}

log_error() {
    log ERROR "$@"
}

# Error handling
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required commands
check_required_commands() {
    local missing=()
    for cmd in "$@"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        error_exit "Missing required commands: ${missing[*]}"
    fi
}

# Retry function
retry() {
    local max_attempts=$1
    shift
    local delay=${2:-1}
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warn "Attempt $attempt/$max_attempts failed. Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Command failed after $max_attempts attempts: $*"
    return 1
}

# Validate environment variable
require_env() {
    local var_name=$1
    local var_value="${!var_name:-}"
    
    if [ -z "$var_value" ]; then
        error_exit "Required environment variable $var_name is not set"
    fi
    
    echo "$var_value"
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || error_exit "Failed to create directory: $dir"
        log_info "Created directory: $dir"
    fi
}

# Cleanup function registration
cleanup_functions=()
cleanup() {
    for func in "${cleanup_functions[@]}"; do
        $func || true
    done
}

trap cleanup EXIT INT TERM

register_cleanup() {
    cleanup_functions+=("$1")
}

# Temporary file/directory management
temp_files=()
cleanup_temp_files() {
    for file in "${temp_files[@]}"; do
        [ -e "$file" ] && rm -rf "$file" || true
    done
}

register_cleanup cleanup_temp_files

create_temp_file() {
    local tmpfile
    tmpfile=$(mktemp) || error_exit "Failed to create temporary file"
    temp_files+=("$tmpfile")
    echo "$tmpfile"
}

create_temp_dir() {
    local tmpdir
    tmpdir=$(mktemp -d) || error_exit "Failed to create temporary directory"
    temp_files+=("$tmpdir")
    echo "$tmpdir"
}

# Wait for condition
wait_for() {
    local condition=$1
    local timeout=${2:-60}
    local interval=${3:-5}
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition"; then
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    return 1
}

# Validate URL
validate_url() {
    local url=$1
    if [[ ! $url =~ ^https?:// ]]; then
        error_exit "Invalid URL format: $url"
    fi
}

# Check service health
check_service_health() {
    local url=$1
    local timeout=${2:-10}
    
    if curl -f -s -m "$timeout" "$url" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

