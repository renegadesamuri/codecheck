# CodeCheck Security Setup Guide

This guide will walk you through setting up the CodeCheck API with proper security configurations.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Environment Configuration](#environment-configuration)
3. [Generating Secure Secrets](#generating-secure-secrets)
4. [Docker Compose Setup](#docker-compose-setup)
5. [Production Deployment](#production-deployment)
6. [Security Best Practices](#security-best-practices)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Development Setup (5 minutes)

```bash
# 1. Navigate to the project directory
cd /Users/raulherrera/autonomous-learning/codecheck

# 2. Copy the development environment template
cp api/.env.development api/.env

# 3. Generate a secure JWT secret key
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# 4. Edit api/.env and add:
#    - Your Claude API key (get from https://console.anthropic.com/)
#    - The generated JWT_SECRET_KEY
#    - A secure database password

# 5. Start all services
docker-compose up -d

# 6. Check the services are running
docker-compose ps

# 7. Access the API
# - API: http://localhost:8000
# - API Docs: http://localhost:8000/docs
# - Health Check: http://localhost:8000/health
```

---

## Environment Configuration

### Required Environment Variables

The following environment variables **MUST** be set before starting the application:

| Variable | Description | Example |
|----------|-------------|---------|
| `JWT_SECRET_KEY` | Secret key for JWT token signing (min 32 chars) | `UZJxCq8K1X9zY2vM3n4b5c6d7e8f9g0h1i2j3k4l` |
| `DB_PASSWORD` | PostgreSQL database password (min 16 chars) | `MySecureDbPass2024!@#$` |
| `CLAUDE_API_KEY` | Anthropic Claude API key | `sk-ant-api03-xxx...` |

### Optional but Recommended

| Variable | Description | Default |
|----------|-------------|---------|
| `REDIS_PASSWORD` | Redis authentication password | _(none)_ |
| `SESSION_SECRET` | Session signing secret | _(uses JWT_SECRET_KEY)_ |
| `ALLOWED_ORIGINS` | CORS allowed origins (comma-separated) | `http://localhost:3000` |

---

## Generating Secure Secrets

### Method 1: Python (Recommended)

```bash
# Generate a 32-character URL-safe secret
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### Method 2: OpenSSL

```bash
# Generate a 32-byte hex secret
openssl rand -hex 32
```

### Method 3: Online Generator

Visit [RandomKeygen.com](https://randomkeygen.com/) and use a "Fort Knox Password"

⚠️ **Security Note:** Never use the same secret for multiple environments or services!

---

## Docker Compose Setup

### File Structure

```
codecheck/
├── docker-compose.yml       # Main Docker configuration
├── .gitignore              # Prevents committing secrets
├── api/
│   ├── .env               # Your secrets (DO NOT COMMIT!)
│   ├── .env.example       # Template with all options
│   ├── .env.development   # Safe development defaults
│   └── ...
└── database/
    └── schema.sql         # Database initialization
```

### Configuration Files

1. **`.env.example`** - Complete template with all available options and documentation
2. **`.env.development`** - Safe defaults for local development
3. **`.env`** - Your actual configuration (created by you, never committed)

### Environment Variable Loading

Docker Compose loads environment variables in this order:

1. Environment variables set in your shell
2. `.env` file in the project root
3. `.env` file in the api directory (preferred)
4. Default values in `docker-compose.yml`

---

## Production Deployment

### Pre-Deployment Checklist

Before deploying to production, complete this checklist:

#### Security Configuration

- [ ] Generated strong `JWT_SECRET_KEY` (32+ characters, random)
- [ ] Generated strong `SESSION_SECRET` (32+ characters, random)
- [ ] Set secure `DB_PASSWORD` (16+ characters, mixed case, numbers, symbols)
- [ ] Set secure `REDIS_PASSWORD` (16+ characters)
- [ ] Obtained valid `CLAUDE_API_KEY` from Anthropic
- [ ] Never committed `.env` file to version control

#### Application Settings

- [ ] Set `ENVIRONMENT=production`
- [ ] Set `DEBUG=false`
- [ ] Set `LOG_LEVEL=INFO` or `WARNING`
- [ ] Configured `ALLOWED_ORIGINS` to specific domains (no wildcard!)
- [ ] Set appropriate `API_WORKERS` (2-4 per CPU core)

#### Docker Configuration

- [ ] Removed `--reload` flag from uvicorn command
- [ ] Set volume mounts to read-only where appropriate
- [ ] Configured resource limits appropriately for your server
- [ ] Set up proper logging and monitoring
- [ ] Enabled health checks

#### Network and Access

- [ ] Configured firewall rules
- [ ] Set up SSL/TLS certificates
- [ ] Configured reverse proxy (nginx, Caddy, etc.)
- [ ] Rate limiting enabled
- [ ] Database not exposed to public internet

### Production Environment File

```bash
# Create production environment file
cp api/.env.example api/.env.production

# Edit with production values
nano api/.env.production
```

**Minimum Production Configuration:**

```bash
# Security (CHANGE ALL OF THESE!)
JWT_SECRET_KEY=<generate-using-python-command-above>
SESSION_SECRET=<generate-using-python-command-above>
DB_PASSWORD=<strong-database-password>
REDIS_PASSWORD=<strong-redis-password>
CLAUDE_API_KEY=<your-claude-api-key>

# Environment
ENVIRONMENT=production
DEBUG=false
LOG_LEVEL=INFO

# CORS (replace with your actual domains)
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com

# Database
DB_HOST=postgres
DB_PORT=5432
DB_USER=postgres
DB_NAME=codecheck

# Redis
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0

# API
API_PORT=8000
API_WORKERS=4

# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_PER_MINUTE=60
AI_RATE_LIMIT_PER_MINUTE=10
```

### Deploy to Production

```bash
# 1. Set up environment file
cp api/.env.example api/.env.production
# Edit api/.env.production with secure values

# 2. Export environment for docker-compose
export ENVIRONMENT=production

# 3. Build images
docker-compose build --no-cache

# 4. Start services
docker-compose --env-file api/.env.production up -d

# 5. Verify services
docker-compose ps
docker-compose logs -f api

# 6. Test health endpoints
curl https://yourdomain.com/health
```

---

## Security Best Practices

### 1. Secret Management

**DO:**
- ✅ Use environment variables for all secrets
- ✅ Generate strong, random secrets (32+ characters)
- ✅ Use different secrets for each environment
- ✅ Rotate secrets regularly (every 90 days minimum)
- ✅ Use a secrets manager in production (AWS Secrets Manager, HashiCorp Vault, etc.)

**DON'T:**
- ❌ Never commit `.env` files to version control
- ❌ Never use default/example secrets in production
- ❌ Never share secrets via email or chat
- ❌ Never log secrets to application logs
- ❌ Never use the same secret across multiple services

### 2. Database Security

```bash
# Strong password requirements:
# - Minimum 16 characters
# - Mix of uppercase, lowercase, numbers, and symbols
# - Not based on dictionary words
# - Unique to this application

# Example of generating a strong password:
python3 -c "import secrets, string; chars = string.ascii_letters + string.digits + '!@#$%^&*'; print(''.join(secrets.choice(chars) for _ in range(20)))"
```

### 3. CORS Configuration

In **development**, you can use:
```bash
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173
```

In **production**, be specific:
```bash
ALLOWED_ORIGINS=https://yourdomain.com,https://app.yourdomain.com
```

**Never use** `ALLOWED_ORIGINS=*` in production!

### 4. Rate Limiting

Configure appropriate rate limits to prevent abuse:

```bash
# General API endpoints
RATE_LIMIT_PER_MINUTE=60

# AI-powered endpoints (more expensive)
AI_RATE_LIMIT_PER_MINUTE=10
```

### 5. Logging

**DO log:**
- Authentication attempts (success and failure)
- API endpoint access
- Errors and exceptions
- Database queries (in development only)

**DON'T log:**
- Passwords or secrets
- Full API keys or tokens
- Personal identifiable information (PII)
- Credit card numbers

### 6. Docker Security

```yaml
# Run as non-root user
user: "1000:1000"

# Limit resources
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 1G

# Read-only volumes in production
volumes:
  - ./api:/app:ro
```

---

## Troubleshooting

### Issue: Docker Compose fails with "Database password must be set"

**Solution:**
```bash
# Check if .env file exists
ls -la api/.env

# If not, create it from template
cp api/.env.development api/.env

# Or create minimal .env
cat > api/.env << EOF
DB_PASSWORD=your_secure_password_here
JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
CLAUDE_API_KEY=your_claude_api_key_here
EOF
```

### Issue: API container fails health check

**Solution:**
```bash
# Check API logs
docker-compose logs api

# Check if port is available
netstat -an | grep 8000

# Test health endpoint directly
docker-compose exec api curl http://localhost:8000/health
```

### Issue: Database connection fails

**Solution:**
```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Check PostgreSQL logs
docker-compose logs postgres

# Verify database credentials
docker-compose exec postgres psql -U postgres -d codecheck -c "SELECT 1"

# Test connection from API container
docker-compose exec api python -c "import psycopg2; conn = psycopg2.connect('postgresql://postgres:${DB_PASSWORD}@postgres:5432/codecheck'); print('Connected!')"
```

### Issue: Redis connection fails

**Solution:**
```bash
# Check Redis is running
docker-compose ps redis

# Test Redis connection
docker-compose exec redis redis-cli ping

# If using password
docker-compose exec redis redis-cli -a your_redis_password ping
```

### Issue: CORS errors in browser

**Solution:**
```bash
# Check ALLOWED_ORIGINS in api/.env
grep ALLOWED_ORIGINS api/.env

# Add your frontend URL
echo "ALLOWED_ORIGINS=http://localhost:3000,https://yourdomain.com" >> api/.env

# Restart API service
docker-compose restart api
```

### Issue: Claude API errors

**Solution:**
```bash
# Verify API key is set
docker-compose exec api printenv CLAUDE_API_KEY

# Test Claude API connection
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":100,"messages":[{"role":"user","content":"Hello"}]}'
```

---

## Additional Resources

### Documentation

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/auth-methods.html)
- [Anthropic Claude API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api)

### Security Tools

- [OWASP Security Guidelines](https://owasp.org/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [Python Security](https://python.readthedocs.io/en/latest/library/secrets.html)

### Monitoring and Logging

- [Sentry](https://sentry.io/) - Error tracking
- [Prometheus](https://prometheus.io/) - Metrics collection
- [Grafana](https://grafana.com/) - Visualization
- [ELK Stack](https://www.elastic.co/elastic-stack) - Log aggregation

---

## Support

If you encounter issues not covered in this guide:

1. Check the application logs: `docker-compose logs -f api`
2. Check the database logs: `docker-compose logs -f postgres`
3. Verify all required environment variables are set
4. Ensure all secrets are properly generated and unique
5. Review the security checklist above

---

## Version History

- **1.0.0** (2025-11-19) - Initial security setup guide

---

**Remember:** Security is not a one-time setup. Regularly review and update your security configurations, rotate secrets, and stay informed about security best practices.
