# Production Deployment Guide for CodeCheck

## 🎯 Problem
Your current setup uses hardcoded local IP addresses, which means:
- ❌ Only works on your local network
- ❌ Only works when your Mac is running
- ❌ Won't work for other users
- ❌ Can't publish to App Store like this

## ✅ Solution: Deploy Backend to Cloud

---

## Step 1: Choose a Hosting Provider

### Recommended: Render.com (Free Tier Available)

**Why Render?**
- ✅ Free tier (great for starting)
- ✅ Easy deployment
- ✅ Auto-detects FastAPI/Python
- ✅ Automatic HTTPS
- ✅ Good performance

**Free Tier Limits:**
- 750 hours/month (plenty for testing)
- Sleeps after 15 min of inactivity
- Wakes up on first request (may take 30s)

---

## Step 2: Deploy Your Backend to Render

### A. Prepare Your Backend

1. **Make sure you have these files** in your backend repo:

**`requirements.txt`** - List your Python dependencies:
```txt
fastapi
uvicorn[standard]
sqlalchemy
psycopg2-binary
python-jose[cryptography]
passlib[bcrypt]
python-multipart
# ... any other dependencies
```

**`render.yaml`** (optional but recommended):
```yaml
services:
  - type: web
    name: codecheck-api
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: uvicorn main:app --host 0.0.0.0 --port $PORT
    envVars:
      - key: PYTHON_VERSION
        value: 3.11
      - key: DATABASE_URL
        fromDatabase:
          name: codecheck-db
          property: connectionString
```

**`Procfile`** (alternative to render.yaml):
```
web: uvicorn main:app --host 0.0.0.0 --port $PORT
```

2. **Update your backend code** to use environment variables:

```python
# In your FastAPI app
import os

# Get port from environment (Render will set this)
PORT = int(os.getenv("PORT", 8000))

# Database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./codecheck.db")

# Run the app
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT)
```

### B. Deploy to Render

1. **Sign up**: https://render.com
2. **Create New Web Service**:
   - Click "New +" → "Web Service"
   - Connect your GitHub/GitLab repo
   - Or use "Deploy from Git URL"

3. **Configure Service**:
   - **Name**: `codecheck-api`
   - **Environment**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - **Plan**: Free

4. **Add Environment Variables**:
   - `SECRET_KEY`: Your JWT secret
   - `DATABASE_URL`: Your database connection string
   - Any other config your backend needs

5. **Deploy**: Click "Create Web Service"
   - First deploy takes 5-10 minutes
   - You'll get a URL like: `https://codecheck-api.onrender.com`

### C. Test Your Deployment

```bash
# Test root endpoint
curl https://codecheck-api.onrender.com/

# Test health check
curl https://codecheck-api.onrender.com/health

# Test auth endpoint
curl -X POST https://codecheck-api.onrender.com/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

---

## Step 3: Update Your iOS App

### Option A: Use the New APIConfiguration Class

I created `APIConfiguration.swift` for you. Update your services to use it:

**Update AuthService.swift:**
```swift
// In AuthService.swift, replace the baseURL initialization
class AuthService: ObservableObject {
    private let baseURL: String
    
    init() {
        // Use the configuration manager
        self.baseURL = APIConfiguration.shared.baseURL
        self.keychain = KeychainWrapper()
    }
    
    // Remove the old Environment enum
}
```

**Update CodeLookupService.swift:**
```swift
class CodeLookupService {
    private let baseURL: String
    
    init(authService: AuthService? = nil) {
        // Use the configuration manager
        self.baseURL = APIConfiguration.shared.baseURL
        self.authService = authService
    }
}
```

**Update APIConfiguration.swift with your production URL:**
```swift
private var productionURL: String {
    return "https://codecheck-api.onrender.com"  // Your actual Render URL
}
```

### Option B: Quick Manual Update

Or just update the existing code directly:

**In AuthService.swift:**
```swift
case .production:
    return "https://codecheck-api.onrender.com"  // Your Render URL
```

**In CodeLookupService.swift:**
```swift
// Change the baseURL initialization:
if useCustomServer, let customURL = customServerURL, !customURL.isEmpty {
    self.baseURL = customURL
} else {
    #if DEBUG
    // Development
    #if targetEnvironment(simulator)
    self.baseURL = "http://localhost:8000"
    #else
    self.baseURL = "http://10.0.0.214:8000"
    #endif
    #else
    // Production - use cloud backend
    self.baseURL = "https://codecheck-api.onrender.com"
    #endif
}
```

---

## Step 4: Update Your Build Configuration

### For Debug Builds (Development)
- Uses local backend
- `http://localhost:8000` on Simulator
- `http://YOUR_IP:8000` on Device

### For Release Builds (Production)
- Uses cloud backend
- `https://your-app.onrender.com`
- Works for all users

**Set build configuration in Xcode:**
1. Select your scheme
2. Edit Scheme → Run → Build Configuration → Debug (for dev)
3. Edit Scheme → Archive → Build Configuration → Release (for production)

---

## Step 5: Test Everything

### Test Development Build
```bash
# Run in Xcode with Debug configuration
# Should connect to http://localhost:8000
```

### Test Production Build
```bash
# In Xcode:
# Product → Archive
# Should connect to https://your-app.onrender.com
```

---

## Step 6: Handle Render Free Tier Sleep

Render free tier sleeps after 15 minutes of inactivity. Add wake-up handling:

```swift
// In your AuthService or NetworkManager
func wakeUpServer() async {
    guard APIConfiguration.shared.baseURL.contains("onrender.com") else {
        return // Not on Render, no need to wake up
    }
    
    // Ping the server to wake it up
    guard let url = URL(string: APIConfiguration.shared.baseURL) else { return }
    
    do {
        let _ = try await URLSession.shared.data(from: url)
        // Wait a bit for server to fully wake up
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    } catch {
        // Ignore errors, just trying to wake up server
    }
}

// Call before critical operations:
func login(email: String, password: String) async {
    await wakeUpServer() // Wake up if sleeping
    // ... rest of login code
}
```

---

## Alternative Hosting Options

### Railway.app
- Similar to Render
- $5/month free credit
- Steps similar to Render above

### Heroku
- More established
- No free tier anymore
- Starting at $7/month
- Very reliable

### Fly.io
- Great performance
- Free tier available
- More complex setup

### Self-Hosted VPS
- DigitalOcean, Linode, Vultr
- $5-10/month
- More control but more setup
- Need to handle: server setup, security, SSL, updates

---

## Cost Breakdown

| Provider | Free Tier | Paid Tier | Best For |
|----------|-----------|-----------|----------|
| Render | ✅ 750hrs/month | $7/mo | Getting started |
| Railway | ✅ $5 credit | $5+/mo | Small apps |
| Heroku | ❌ | $7/mo | Established apps |
| Fly.io | ✅ Limited | $1.94+/mo | Global users |
| VPS | ❌ | $5+/mo | Full control |

---

## Database Considerations

Your backend probably needs a database. Options:

### Render PostgreSQL (Recommended)
- Free tier available
- 90 days, then expires (need to migrate)
- Easy to set up with your web service

### Supabase (PostgreSQL)
- Free tier: 500MB database
- Good free tier limits
- Easy integration

### PlanetScale (MySQL)
- Free tier: 5GB storage
- Generous limits
- Great performance

---

## Security Checklist

Before deploying to production:

- [ ] Use HTTPS (not HTTP)
- [ ] Set strong SECRET_KEY in environment variables
- [ ] Don't commit secrets to Git
- [ ] Enable CORS properly (restrict origins)
- [ ] Use environment variables for all config
- [ ] Set up proper database backups
- [ ] Enable rate limiting
- [ ] Add monitoring/logging
- [ ] Test authentication thoroughly
- [ ] Validate all user inputs

---

## App Store Submission

Before submitting to App Store:

1. **Update Info.plist**:
   - Remove `NSAllowsLocalNetworking` (or restrict to debug builds)
   - Add `NSAppTransportSecurity` exceptions only if needed

2. **Set Build Configuration**:
   - Archive builds should use `.production` environment
   - Never ship with `.development` URLs

3. **Test Release Build**:
   - Archive → Distribute → Development/Ad Hoc
   - Test on real device without Xcode
   - Verify connects to production backend

---

## Monitoring Your Backend

### Render Dashboard
- View logs
- Monitor CPU/memory usage
- See deploy history
- Check service health

### Add Health Check Endpoint
```python
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow(),
        "version": "1.0.0"
    }
```

### Monitor from iOS App
```swift
// Periodically check backend health
Task {
    let (success, message) = await APIConfiguration.shared.testConnection()
    if !success {
        // Show warning to user or retry
    }
}
```

---

## Troubleshooting Production

### "Cannot connect to server"
- ✅ Check Render dashboard - is service running?
- ✅ Check service logs for errors
- ✅ Verify URL is correct in app
- ✅ Test URL in browser

### "SSL/Certificate errors"
- ✅ Render provides automatic HTTPS
- ✅ Make sure you're using `https://` not `http://`
- ✅ Check iOS allows HTTPS connections

### "Service sleeping"
- ✅ Normal on Render free tier
- ✅ First request wakes it up (takes 30s)
- ✅ Consider paid tier for always-on
- ✅ Implement wake-up handler in app

---

## Next Steps

1. **Deploy backend to Render** following steps above
2. **Get your production URL** (e.g., `https://codecheck-api.onrender.com`)
3. **Update `APIConfiguration.swift`** with your production URL
4. **Test with release build** before App Store submission
5. **Monitor your backend** in Render dashboard

---

## Quick Start Commands

```bash
# 1. Get your Mac's IP (for local testing)
ipconfig getifaddr en0

# 2. Test local backend
curl http://localhost:8000

# 3. Test production backend (after deploying)
curl https://your-app.onrender.com

# 4. Update IP in your code
./update_ip.sh

# 5. Clean Xcode build
# Xcode → Product → Clean Build Folder
```

---

## Summary

**For Development (You):**
- Use local backend: `http://localhost:8000` or `http://YOUR_IP:8000`
- Debug builds automatically use development URLs

**For Production (All Users):**
- Deploy backend to cloud (Render, Railway, etc.)
- Get production URL: `https://your-app.onrender.com`
- Release builds automatically use production URL
- Works for everyone, everywhere

**Answer to Your Question:**
> "What happens if someone else downloads the app?"

**With local backend**: ❌ Won't work - they can't reach your Mac

**With cloud backend**: ✅ Works perfectly - everyone connects to the same cloud server

---

Need help deploying? Let me know which hosting provider you choose!
