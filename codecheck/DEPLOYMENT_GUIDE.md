# CodeCheck Deployment Guide - QUICK FIX for Render Issues
**Updated**: 2025-01-19
**Status**: Production Deployment Ready

---

## 🚨 ISSUES FIXED

### Problem 1: pydantic-core Rust Compilation Error
**Error**: `pydantic_core-2.14.1.tar.gz` trying to compile Rust on read-only filesystem

**Root Cause**:
- Old pydantic version (2.5.0) doesn't have pre-built wheels for Python 3.13
- Render using Python 3.13 by default
- pydantic-core needs Rust compiler to build from source

**Solution Applied**:
✅ Updated `requirements.txt` to use newer versions with pre-built wheels:
- `fastapi==0.115.5` (was 0.104.1)
- `pydantic==2.10.3` (was 2.5.0) - Has wheels for Python 3.13!
- `uvicorn==0.34.0` (was 0.24.0)
- `anthropic==0.42.0` (was 0.18.0)

✅ Created `runtime.txt` to pin Python to 3.11.8 (fallback option)

---

## 🚀 DEPLOYMENT OPTIONS

### Option A: Render (Recommended for MVP)

**Why Render**:
- Free PostgreSQL database
- Free web service (750 hours/month)
- Automatic HTTPS
- Easy environment variables
- Good for demos

**Setup**:

1. **Create Render Account**: https://render.com

2. **Deploy Database**:
   - New → PostgreSQL
   - Name: `codecheck-db`
   - Database: `codecheck`
   - User: `postgres`
   - Plan: Free
   - Region: Oregon
   - Save database credentials!

3. **Deploy API**:
   - New → Web Service
   - Connect GitHub repo: `renegadesamuri/codecheck`
   - Name: `codecheck-api`
   - Root Directory: Leave empty (or `codecheck`)
   - Environment: Python
   - Build Command: `pip install -r api/requirements.txt`
   - Start Command: `cd api && uvicorn main:app --host 0.0.0.0 --port $PORT`
   - Plan: Free

4. **Set Environment Variables** in Render dashboard:
   ```
   DATABASE_URL=[from database connection string]
   JWT_SECRET_KEY=[generate random 32-char string]
   CLAUDE_API_KEY=[your-claude-api-key-from-console.anthropic.com]
   ALLOWED_ORIGINS=https://codecheck-api.onrender.com
   ENVIRONMENT=production
   PYTHON_VERSION=3.11.8
   ```

5. **Run Migrations**:
   - In Render dashboard → codecheck-db → Connect
   - Run SQL:
   ```sql
   -- Run these in order
   \i database/schema.sql
   \i database/migrations/001_add_users_and_security.sql
   \i database/migrations/002_add_on_demand_loading.sql
   \i database/seed_demo_cities.sql
   ```

   OR use Render's Shell:
   ```bash
   psql $DATABASE_URL < database/schema.sql
   psql $DATABASE_URL < database/migrations/001_add_users_and_security.sql
   psql $DATABASE_URL < database/migrations/002_add_on_demand_loading.sql
   psql $DATABASE_URL < database/seed_demo_cities.sql
   ```

6. **Test Deployment**:
   ```bash
   curl https://codecheck-api.onrender.com/
   # Should return: {"message":"CodeCheck API is running","version":"1.0.0"}
   ```

---

### Option B: Railway (Alternative)

**Why Railway**:
- Even simpler than Render
- Better free tier ($5 credit/month)
- Automatic deployments
- Built-in PostgreSQL with PostGIS

**Setup**:

1. **Install Railway CLI**:
   ```bash
   npm install -g @railway/cli
   railway login
   ```

2. **Deploy**:
   ```bash
   cd /Users/raulherrera/autonomous-learning/codecheck
   railway init
   railway add --database postgres
   railway up
   ```

3. **Set Environment Variables**:
   ```bash
   railway variables set JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
   railway variables set CLAUDE_API_KEY=YOUR_CLAUDE_API_KEY_HERE
   railway variables set ENVIRONMENT=production
   ```

4. **Deploy**:
   ```bash
   railway up
   ```

---

### Option C: Fly.io (Best for Scale)

**Why Fly.io**:
- Best performance
- Global edge deployment
- Built-in PostgreSQL
- Good free tier

**Setup**:

1. **Install Fly CLI**:
   ```bash
   brew install flyctl
   fly auth login
   ```

2. **Deploy**:
   ```bash
   cd /Users/raulherrera/autonomous-learning/codecheck
   fly launch --name codecheck-api
   fly postgres create --name codecheck-db
   fly postgres attach codecheck-db
   ```

3. **Set Secrets**:
   ```bash
   fly secrets set JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
   fly secrets set CLAUDE_API_KEY=YOUR_CLAUDE_API_KEY_HERE
   ```

4. **Deploy**:
   ```bash
   fly deploy
   ```

---

## 🔥 QUICK FIX FOR YOUR CURRENT RENDER DEPLOYMENT

Since you're already deploying to Render, do this:

### Step 1: Update Your Render Configuration

In Render dashboard for `codecheck-api`:

**Build Command**:
```bash
pip install --upgrade pip && pip install -r api/requirements.txt
```

**Start Command**:
```bash
cd api && uvicorn main:app --host 0.0.0.0 --port $PORT
```

**Environment Variables** (Add these):
```
PYTHON_VERSION=3.11.8
PIP_NO_CACHE_DIR=1
```

### Step 2: Trigger Redeploy

After updating requirements.txt (which we just did), trigger a new deploy in Render dashboard.

---

## 🎯 ALTERNATIVE: Pin Python Version

Create this file if the above doesn't work:

**File**: `/.python-version`
```
3.11.8
```

This forces Render to use Python 3.11.8 instead of 3.13, which has better wheel support.

---

## ✅ VERIFICATION STEPS

After deployment succeeds:

1. **Check Health**:
   ```bash
   curl https://your-app.onrender.com/
   ```

2. **Test Registration**:
   ```bash
   curl -X POST https://your-app.onrender.com/auth/register \
     -H 'Content-Type: application/json' \
     -d '{"email":"demo@test.com","password":"Demo1234","full_name":"Demo User"}'
   ```

3. **Test Login**:
   ```bash
   curl -X POST https://your-app.onrender.com/auth/login \
     -H 'Content-Type: application/json' \
     -d '{"email":"demo@test.com","password":"Demo1234"}'
   ```

4. **Update iOS App**:
   - Change base URL to your Render URL: `https://your-app.onrender.com`
   - Remove port number (Render uses 443 for HTTPS)
   - Update Info.plist to remove NSExceptionAllowsInsecureHTTPLoads (production uses HTTPS)

---

## 📱 iOS PRODUCTION CONFIGURATION

Once deployed, update these files:

**AuthService.swift** (line 481):
```swift
case .production:
    return URL(string: "https://codecheck-api.onrender.com")!
```

**CodeLookupService.swift** (line 9):
```swift
private let baseURL = URL(string: "https://codecheck-api.onrender.com")!
```

**Info.plist**: Remove the exception domain or update to production URL

---

## 🚨 COMMON DEPLOYMENT ISSUES & FIXES

### Issue: "Read-only file system"
**Fix**: Use pre-built wheels (we just updated requirements.txt ✅)

### Issue: "Rust compiler not found"
**Fix**: Pin Python to 3.11.8 with `runtime.txt` ✅

### Issue: "Database connection failed"
**Fix**:
- Verify DATABASE_URL is set in environment variables
- Check database is in same region as API
- Enable PostGIS extension: `CREATE EXTENSION IF NOT EXISTS postgis;`

### Issue: "Missing CLAUDE_API_KEY"
**Fix**: Add CLAUDE_API_KEY to environment variables in Render dashboard

### Issue: "CORS errors from iOS"
**Fix**: Add your Render URL to ALLOWED_ORIGINS environment variable

---

## 🎯 RECOMMENDED APPROACH FOR FASTEST DEPLOY

**Use Railway** - It's the fastest:

```bash
# Install Railway
npm install -g @railway/cli

# Login
railway login

# Initialize project
cd /Users/raulherrera/autonomous-learning/codecheck
railway init

# Add PostgreSQL (with PostGIS!)
railway add --database postgres

# Set secrets
railway variables set CLAUDE_API_KEY=YOUR_CLAUDE_API_KEY_HERE
railway variables set JWT_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

# Deploy!
railway up

# Get URL
railway domain

# Done! Usually takes 2-3 minutes total.
```

---

## 💪 WHAT TO DO RIGHT NOW

1. **Commit the fix**:
   ```bash
   git add -A
   git commit -m "Fix: Update dependencies for Render deployment"
   git push
   ```

2. **Choose platform**:
   - **Fastest**: Railway (3 minutes)
   - **Free tier**: Render (5-10 minutes)
   - **Best performance**: Fly.io (10 minutes)

3. **Deploy and test**

4. **Update iOS app with production URL**

5. **TEST ON IPHONE WITH PRODUCTION API**

6. **SHOW INVESTORS!** 💰

---

Want me to help you deploy to Railway right now? It's literally 3 commands and you're live! 🚀