#!/bin/bash

# ============================================================================
# CodeCheck Security Setup Script
# ============================================================================
# This script helps you quickly set up secure environment variables for
# the CodeCheck API project.
#
# Usage: ./setup-security.sh [environment]
#   environment: dev (default), prod, or staging
#
# What this script does:
# 1. Generates secure random secrets
# 2. Creates .env files from templates
# 3. Prompts for required values (Claude API key, passwords, etc.)
# 4. Validates configuration
# 5. Sets appropriate file permissions
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-dev}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_ENV_FILE="${PROJECT_DIR}/.env"
API_ENV_FILE="${PROJECT_DIR}/api/.env"

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

generate_secret() {
    local length="${1:-32}"
    python3 -c "import secrets; print(secrets.token_urlsafe($length))"
}

generate_password() {
    local length="${1:-20}"
    python3 -c "import secrets, string; chars = string.ascii_letters + string.digits + '!@#$%^&*'; print(''.join(secrets.choice(chars) for _ in range($length)))"
}

prompt_for_value() {
    local prompt="$1"
    local default="$2"
    local secret="${3:-false}"
    local value=""

    if [ "$secret" = "true" ]; then
        read -s -p "$prompt" value
        echo
    else
        read -p "$prompt" value
    fi

    if [ -z "$value" ] && [ -n "$default" ]; then
        value="$default"
    fi

    echo "$value"
}

check_dependencies() {
    local missing=()

    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi

    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi

    if ! command -v docker-compose &> /dev/null; then
        missing+=("docker-compose")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing[*]}"
        print_info "Please install missing dependencies and try again."
        exit 1
    fi

    print_success "All dependencies are installed"
}

# ============================================================================
# Main Setup Functions
# ============================================================================

setup_development() {
    print_header "Setting up DEVELOPMENT Environment"

    print_info "Generating secure secrets..."
    JWT_SECRET=$(generate_secret 32)
    DB_PASSWORD=$(generate_password 16)

    print_info "Please provide the following information:"
    echo

    CLAUDE_API_KEY=$(prompt_for_value "Claude API Key (get from https://console.anthropic.com/): " "" true)

    if [ -z "$CLAUDE_API_KEY" ]; then
        print_warning "Claude API key not provided. You'll need to add it manually later."
        CLAUDE_API_KEY="your_claude_api_key_here"
    fi

    # Create root .env file
    cat > "$ROOT_ENV_FILE" << EOF
# CodeCheck Development Environment
# Auto-generated on $(date)

# Database
DB_NAME=codecheck
DB_USER=postgres
DB_PASSWORD=${DB_PASSWORD}
DB_PORT=5432

# Security
JWT_SECRET_KEY=${JWT_SECRET}
SESSION_SECRET=${JWT_SECRET}

# Claude API
CLAUDE_API_KEY=${CLAUDE_API_KEY}
CLAUDE_MODEL=claude-3-5-sonnet-20241022
CLAUDE_MAX_TOKENS=4096

# Redis
REDIS_PORT=6379
REDIS_PASSWORD=

# Application
ENVIRONMENT=development
DEBUG=true
LOG_LEVEL=DEBUG

# API
API_PORT=8000
API_WORKERS=1

# CORS
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:8080

# Rate Limiting (relaxed for development)
RATE_LIMIT_ENABLED=false
RATE_LIMIT_PER_MINUTE=1000

# Feature Flags
FEATURE_AUTH_ENABLED=true
FEATURE_AI_EXPLANATIONS=true

# Docker
UID=$(id -u)
GID=$(id -g)
PYTHON_VERSION=3.11
VOLUME_MODE=rw
UVICORN_RELOAD=--reload
EOF

    # Copy to API directory
    cp "$ROOT_ENV_FILE" "$API_ENV_FILE"

    print_success "Development environment configured"
}

setup_production() {
    print_header "Setting up PRODUCTION Environment"

    print_warning "PRODUCTION setup requires careful configuration!"
    print_info "This script will generate secure secrets, but you MUST review all settings."
    echo

    read -p "Continue with production setup? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Setup cancelled."
        exit 0
    fi

    print_info "Generating secure secrets..."
    JWT_SECRET=$(generate_secret 48)
    SESSION_SECRET=$(generate_secret 48)
    DB_PASSWORD=$(generate_password 24)
    REDIS_PASSWORD=$(generate_password 20)

    print_info "Please provide the following information:"
    echo

    CLAUDE_API_KEY=$(prompt_for_value "Claude API Key (PRODUCTION): " "" true)
    ALLOWED_ORIGINS=$(prompt_for_value "Allowed Origins (comma-separated, e.g., https://yourdomain.com): ")
    API_WORKERS=$(prompt_for_value "Number of API workers (2-4 per CPU core): " "4")

    if [ -z "$CLAUDE_API_KEY" ]; then
        print_error "Claude API key is required for production!"
        exit 1
    fi

    if [ -z "$ALLOWED_ORIGINS" ]; then
        print_error "Allowed origins must be specified for production!"
        exit 1
    fi

    # Create root .env file
    cat > "$ROOT_ENV_FILE" << EOF
# CodeCheck Production Environment
# Auto-generated on $(date)
# IMPORTANT: Review all settings before deploying!

# Database
DB_NAME=codecheck
DB_USER=postgres
DB_PASSWORD=${DB_PASSWORD}
DB_PORT=5432
POSTGRES_SHARED_BUFFERS=512MB
POSTGRES_MAX_CONNECTIONS=200

# Security
JWT_SECRET_KEY=${JWT_SECRET}
SESSION_SECRET=${SESSION_SECRET}

# Claude API
CLAUDE_API_KEY=${CLAUDE_API_KEY}
CLAUDE_MODEL=claude-3-5-sonnet-20241022
CLAUDE_MAX_TOKENS=4096

# Redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}

# Application
ENVIRONMENT=production
DEBUG=false
LOG_LEVEL=INFO

# API
API_PORT=8000
API_WORKERS=${API_WORKERS}

# CORS
ALLOWED_ORIGINS=${ALLOWED_ORIGINS}

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60
AI_RATE_LIMIT_PER_MINUTE=10

# Feature Flags
FEATURE_AUTH_ENABLED=true
FEATURE_AI_EXPLANATIONS=true

# Docker
UID=$(id -u)
GID=$(id -g)
PYTHON_VERSION=3.11
VOLUME_MODE=ro
UVICORN_RELOAD=
EOF

    # Copy to API directory
    cp "$ROOT_ENV_FILE" "$API_ENV_FILE"

    print_success "Production environment configured"
    print_warning "IMPORTANT: Review ${ROOT_ENV_FILE} before deploying!"
}

display_summary() {
    print_header "Setup Summary"

    echo "Environment files created:"
    echo "  - ${ROOT_ENV_FILE}"
    echo "  - ${API_ENV_FILE}"
    echo

    if [ "$ENVIRONMENT" = "dev" ]; then
        echo "Development configuration:"
        echo "  - Debug mode: enabled"
        echo "  - Rate limiting: disabled"
        echo "  - Auto-reload: enabled"
    else
        echo "Production configuration:"
        echo "  - Debug mode: disabled"
        echo "  - Rate limiting: enabled"
        echo "  - Auto-reload: disabled"
        echo
        print_warning "REMEMBER TO:"
        echo "  1. Review all configuration in .env files"
        echo "  2. Verify ALLOWED_ORIGINS is correct"
        echo "  3. Test in staging before deploying to production"
        echo "  4. Never commit .env files to version control"
        echo "  5. Set up SSL/TLS certificates"
        echo "  6. Configure firewall rules"
    fi

    echo
    print_info "Next steps:"
    echo "  1. Review the generated .env files"
    echo "  2. Make any necessary adjustments"
    echo "  3. Run: docker-compose up -d"
    echo "  4. Check status: docker-compose ps"
    echo "  5. View logs: docker-compose logs -f api"
}

set_file_permissions() {
    print_info "Setting secure file permissions..."

    # Make .env files readable only by owner
    chmod 600 "$ROOT_ENV_FILE" 2>/dev/null || true
    chmod 600 "$API_ENV_FILE" 2>/dev/null || true

    print_success "File permissions set"
}

backup_existing_env() {
    if [ -f "$ROOT_ENV_FILE" ]; then
        local backup="${ROOT_ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$ROOT_ENV_FILE" "$backup"
        print_info "Backed up existing .env to $backup"
    fi

    if [ -f "$API_ENV_FILE" ]; then
        local backup="${API_ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$API_ENV_FILE" "$backup"
        print_info "Backed up existing api/.env to $backup"
    fi
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    clear

    print_header "CodeCheck Security Setup"

    print_info "Environment: $ENVIRONMENT"
    print_info "Project directory: $PROJECT_DIR"
    echo

    # Check dependencies
    check_dependencies

    # Backup existing files
    backup_existing_env

    # Setup based on environment
    case "$ENVIRONMENT" in
        dev|development)
            setup_development
            ;;
        prod|production)
            setup_production
            ;;
        staging)
            print_error "Staging setup not yet implemented"
            print_info "Use production setup and adjust settings manually"
            exit 1
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            print_info "Valid options: dev, prod"
            exit 1
            ;;
    esac

    # Set permissions
    set_file_permissions

    # Display summary
    display_summary

    print_success "Setup complete!"
}

# Run main function
main

exit 0
