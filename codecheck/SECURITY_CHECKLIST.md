# CodeCheck Security Checklist

Use this checklist to ensure your CodeCheck API deployment is secure.

## Initial Setup

### Environment Files

- [ ] Created `.env` from `.env.example`
- [ ] Created `api/.env` from `api/.env.example`
- [ ] Verified `.env` files are listed in `.gitignore`
- [ ] Set appropriate file permissions (600) for `.env` files
- [ ] Never committed `.env` files to version control

### Secrets Generation

- [ ] Generated strong `JWT_SECRET_KEY` (minimum 32 characters)
  ```bash
  python3 -c "import secrets; print(secrets.token_urlsafe(32))"
  ```

- [ ] Generated strong `SESSION_SECRET` (minimum 32 characters)
  ```bash
  python3 -c "import secrets; print(secrets.token_urlsafe(32))"
  ```

- [ ] Set secure `DB_PASSWORD` (minimum 16 characters, mixed case, numbers, symbols)
  ```bash
  python3 -c "import secrets, string; chars = string.ascii_letters + string.digits + '!@#$%^&*'; print(''.join(secrets.choice(chars) for _ in range(20)))"
  ```

- [ ] Set secure `REDIS_PASSWORD` (optional but recommended)

- [ ] Obtained `CLAUDE_API_KEY` from [Anthropic Console](https://console.anthropic.com/)

- [ ] All secrets are unique (not reused from examples or other projects)

- [ ] All secrets are different for each environment (dev/staging/prod)

---

## Application Configuration

### Environment Settings

- [ ] Set `ENVIRONMENT` appropriately (development/staging/production)

- [ ] Set `DEBUG=false` for production

- [ ] Set appropriate `LOG_LEVEL` (DEBUG for dev, INFO/WARNING for prod)

- [ ] Configured `ALLOWED_ORIGINS` to specific domains (NO wildcards in production!)

- [ ] Set appropriate `API_WORKERS` (2-4 per CPU core for production)

### Database Configuration

- [ ] Database password is strong and unique

- [ ] Database is not exposed to public internet

- [ ] Database backups are configured

- [ ] Database connection pooling is configured appropriately

### Rate Limiting

- [ ] `RATE_LIMIT_ENABLED=true` for production

- [ ] `RATE_LIMIT_PER_MINUTE` set appropriately (60 is reasonable)

- [ ] `AI_RATE_LIMIT_PER_MINUTE` set lower (10 is reasonable)

### Authentication & Authorization

- [ ] JWT tokens have appropriate expiration times

- [ ] Password strength requirements are enforced

- [ ] User roles and permissions are properly configured

---

## Docker Configuration

### Security

- [ ] Services run as non-root users

- [ ] Resource limits are configured (CPU, memory)

- [ ] Health checks are enabled for all services

- [ ] Restart policies are configured (`unless-stopped` or `on-failure`)

- [ ] Network isolation is configured (custom network)

- [ ] Volumes use named volumes (not bind mounts in production)

- [ ] Sensitive files are mounted as read-only (`:ro`)

### Production Specific

- [ ] Removed `--reload` flag from uvicorn command

- [ ] Set appropriate number of workers

- [ ] Volume mounts are read-only where possible (`VOLUME_MODE=ro`)

- [ ] Build arguments are secure (no secrets in build args)

---

## Network & Infrastructure

### CORS Configuration

- [ ] `ALLOWED_ORIGINS` is set to specific domains only

- [ ] No wildcard (`*`) in CORS origins for production

- [ ] Credentials are properly configured for CORS

### SSL/TLS

- [ ] SSL/TLS certificates are configured

- [ ] Certificates are valid and not expired

- [ ] HTTP is redirected to HTTPS

- [ ] HSTS headers are enabled

### Firewall & Access Control

- [ ] Only necessary ports are exposed

- [ ] Database port (5432) is not exposed to internet

- [ ] Redis port (6379) is not exposed to internet

- [ ] API is behind a reverse proxy (nginx, Caddy, etc.)

- [ ] IP whitelisting configured (if applicable)

---

## Monitoring & Logging

### Logging

- [ ] Application logs are configured

- [ ] Log level is appropriate for environment

- [ ] Logs do NOT contain sensitive information (passwords, API keys, etc.)

- [ ] Log rotation is configured

- [ ] Logs are stored securely

### Monitoring

- [ ] Health check endpoints are accessible

- [ ] Metrics collection is configured (optional)

- [ ] Error tracking is configured (Sentry, etc.)

- [ ] Uptime monitoring is configured

- [ ] Database performance monitoring is configured

---

## Data Protection

### Sensitive Data

- [ ] Passwords are hashed (bcrypt)

- [ ] API keys are encrypted at rest

- [ ] Personal information is protected (PII)

- [ ] Data encryption in transit (HTTPS/TLS)

- [ ] Data encryption at rest (if required)

### Backups

- [ ] Database backups are configured

- [ ] Backup retention policy is defined

- [ ] Backups are tested regularly

- [ ] Backups are stored securely (encrypted)

- [ ] Backup restoration procedure is documented

---

## Compliance & Documentation

### Documentation

- [ ] Security setup guide is available (SECURITY_SETUP.md)

- [ ] Environment variables are documented

- [ ] Deployment procedures are documented

- [ ] Incident response plan is documented

- [ ] Security contacts are documented

### Secret Management

- [ ] Secret rotation schedule is defined (every 90 days minimum)

- [ ] Secret rotation procedure is documented

- [ ] Secrets are stored in a secure vault (for production)

- [ ] Access to secrets is logged and monitored

### Compliance

- [ ] GDPR compliance reviewed (if applicable)

- [ ] Data retention policies are defined

- [ ] Privacy policy is updated

- [ ] Terms of service are updated

---

## Testing

### Security Testing

- [ ] Tested authentication and authorization

- [ ] Tested rate limiting

- [ ] Tested CORS configuration

- [ ] Tested with invalid/expired tokens

- [ ] Tested SQL injection prevention

- [ ] Tested XSS prevention

- [ ] Tested CSRF protection

### Integration Testing

- [ ] Tested database connections

- [ ] Tested Redis connections

- [ ] Tested Claude API integration

- [ ] Tested health check endpoints

- [ ] Tested error handling

### Load Testing

- [ ] Load tested API endpoints

- [ ] Load tested database queries

- [ ] Load tested AI endpoints

- [ ] Verified rate limiting under load

---

## Deployment

### Pre-Deployment

- [ ] Reviewed all configuration files

- [ ] Tested in staging environment

- [ ] Performed security audit

- [ ] Reviewed and updated dependencies

- [ ] Scanned for vulnerabilities

### Deployment

- [ ] Used blue-green or rolling deployment

- [ ] Verified zero-downtime deployment

- [ ] Rolled back plan is prepared

- [ ] Deployment is monitored in real-time

### Post-Deployment

- [ ] Verified all services are running

- [ ] Verified health checks pass

- [ ] Verified API endpoints work

- [ ] Verified authentication works

- [ ] Verified database connections

- [ ] Monitored logs for errors

- [ ] Monitored performance metrics

---

## Ongoing Maintenance

### Regular Tasks

- [ ] Review logs weekly

- [ ] Monitor error rates daily

- [ ] Monitor API usage and rate limits

- [ ] Update dependencies monthly

- [ ] Rotate secrets quarterly (90 days)

- [ ] Review access logs monthly

- [ ] Test backups monthly

- [ ] Update documentation as needed

### Security Reviews

- [ ] Quarterly security audits

- [ ] Annual penetration testing

- [ ] Regular vulnerability scanning

- [ ] Review and update security policies

---

## Incident Response

### Preparation

- [ ] Incident response plan documented

- [ ] Contact list for security incidents

- [ ] Escalation procedures defined

- [ ] Communication templates prepared

### Response

- [ ] Monitoring for security incidents

- [ ] Alerting configured for anomalies

- [ ] Procedure for revoking compromised credentials

- [ ] Procedure for emergency shutdowns

---

## Quick Commands Reference

### Generate Secrets

```bash
# JWT Secret (32 chars)
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Secure Password (20 chars)
python3 -c "import secrets, string; chars = string.ascii_letters + string.digits + '!@#$%^&*'; print(''.join(secrets.choice(chars) for _ in range(20)))"
```

### Check Configuration

```bash
# Verify environment variables are set
docker-compose config

# Check if .env is ignored by git
git check-ignore -v .env
git check-ignore -v api/.env
```

### Test Services

```bash
# Test API health
curl http://localhost:8000/health

# Test PostgreSQL
docker-compose exec postgres pg_isready -U postgres

# Test Redis
docker-compose exec redis redis-cli ping

# Test with authentication
curl -X POST http://localhost:8000/check \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"jurisdiction_id":"test","metrics":{}}'
```

---

## Emergency Contacts

### Security Issues

- **Project Lead:** [Your Name] - [Your Email]
- **Security Team:** [Security Email]
- **On-Call:** [On-Call Contact]

### Service Providers

- **Anthropic Support:** support@anthropic.com
- **Hosting Provider:** [Your Provider]
- **Database Provider:** [Your Provider]

---

## Resources

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/auth-methods.html)
- [Anthropic Security](https://www.anthropic.com/security)

---

**Last Updated:** 2025-11-19
**Version:** 1.0.0
**Reviewed By:** [Your Name]

---

## Automated Setup

For a guided setup experience, use the automated setup script:

```bash
# Development setup
./setup-security.sh dev

# Production setup
./setup-security.sh prod
```

This will automatically generate secure secrets and create properly configured `.env` files.
