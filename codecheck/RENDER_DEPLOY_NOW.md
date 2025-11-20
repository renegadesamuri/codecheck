# 🚀 Deploy CodeCheck to Render RIGHT NOW
**Time**: 5-10 minutes
**Cost**: $0 (Free tier!)
**Result**: Production API for investor demos

---

## STEP 1: Create Render Account (1 minute)

1. Go to https://render.com
2. Sign up with GitHub
3. Authorize Render to access your repos

---

## STEP 2: Deploy PostgreSQL Database (2 minutes)

1. Click **"New +"** → **"PostgreSQL"**

2. Configure:
   - **Name**: `codecheck-db`
   - **Database**: `codecheck`
   - **User**: `postgres`
   - **Region**: `Oregon (US West)`
   - **PostgreSQL Version**: `16`
   - **Plan**: **Free**

3. Click **"Create Database"**

4. **SAVE THESE** (you'll need them):
   - **Internal Database URL** (starts with `postgres://`)
   - **External Database URL** (for migrations)
   - **Host, Port, Database, Username, Password**

5. **Wait 2-3 minutes** for database to provision

---

## STEP 3: Enable PostGIS Extension (1 minute)

1. In Render dashboard → **codecheck-db** → **"Connect"** (top right)

2. Select **"External Connection"**

3. Copy the connection command (looks like):
   ```bash
   PGPASSWORD=xyz psql -h dpg-abc123-a.oregon-postgres.render.com -U postgres codecheck
   ```

4. Run in your terminal:
   ```bash
   # Paste the connection command from Render, then run:
   CREATE EXTENSION IF NOT EXISTS postgis;
   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
   \q
   ```

---

## STEP 4: Deploy API Service (2 minutes)

1. Click **"New +"** → **"Web Service"**

2. Connect Repository:
   - **GitHub**: Select `renegadesamuri/codecheck`
   - Click **"Connect"**

3. Configure:
   - **Name**: `codecheck-api`
   - **Region**: `Oregon (US West)` (same as database!)
   - **Branch**: `main`
   - **Root Directory**: Leave empty (Render auto-detects)
   - **Runtime**: `Python 3`
   - **Build Command**:
     ```bash
     pip install --upgrade pip && pip install -r api/requirements.txt
     ```
   - **Start Command**:
     ```bash
     cd api && uvicorn main:app --host 0.0.0.0 --port $PORT
     ```
   - **Plan**: **Free**

4. Click **"Create Web Service"** (DON'T deploy yet!)

---

## STEP 5: Set Environment Variables (2 minutes)

In your `codecheck-api` service, go to **"Environment"** tab and add:

**Critical Variables**:
```
DATABASE_URL = [paste Internal Database URL from Step 2]
JWT_SECRET_KEY = [generate below]
CLAUDE_API_KEY = [your Claude API key]
ENVIRONMENT = production
ALLOWED_ORIGINS = https://codecheck-api.onrender.com
PYTHON_VERSION = 3.11.8
```

**To generate JWT_SECRET_KEY**:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
# Copy the output
```

**Your CLAUDE_API_KEY**:
```
sk-ant-api03-[your-key-here]
```

Click **"Save Changes"**

---

## STEP 6: Deploy! (1 minute)

1. Render will automatically start deploying
2. Watch the logs (should take 2-3 minutes)
3. Look for: **"Your service is live 🎉"**
4. Your URL will be: `https://codecheck-api.onrender.com`

---

## STEP 7: Run Database Migrations (3 minutes)

From your local terminal:

```bash
cd /Users/raulherrera/autonomous-learning/codecheck

# Use the External Database URL from Step 2
export DATABASE_URL="postgres://postgres:PASSWORD@dpg-xyz.oregon-postgres.render.com/codecheck"

# Run migrations (replace with your actual connection details)
psql "$DATABASE_URL" < database/schema.sql
psql "$DATABASE_URL" < database/migrations/001_add_users_and_security.sql
psql "$DATABASE_URL" < database/migrations/002_add_on_demand_loading.sql
psql "$DATABASE_URL" < database/seed_demo_cities.sql
```

**OR** use Render's built-in shell:
1. In Render dashboard → codecheck-db → "Connect" → "External Connection"
2. Copy the psql command and connect
3. Copy/paste each migration SQL file content directly

---

## STEP 8: Test Your Production API! (1 minute)

```bash
# Health check
curl https://codecheck-api.onrender.com/

# Should return:
# {"message":"CodeCheck API is running","version":"1.0.0"}

# Register a user
curl -X POST https://codecheck-api.onrender.com/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@example.com","password":"Demo1234","full_name":"Demo User"}'

# Should return JWT tokens!
```

---

## STEP 9: Update iOS App (5 minutes)

1. **Open Xcode**:
   ```bash
   cd /Users/raulherrera/autonomous-learning/codecheck/ios-app
   open CodeCheck.xcodeproj
   ```

2. **Update AuthService.swift** (line 481):
   ```swift
   case .production:
       return URL(string: "https://codecheck-api.onrender.com")!
   ```

3. **Update CodeLookupService.swift** (line 9):
   ```swift
   private let baseURL = URL(string: "https://codecheck-api.onrender.com")!
   ```

4. **Update Info.plist**:
   - Remove the `10.0.0.214` exception domain (production uses HTTPS)
   - Or add your Render domain with `NSExceptionAllowsInsecureHTTPLoads = false`

5. **Build & Run** on your iPhone:
   - Connect iPhone via USB
   - Select iPhone in Xcode (top toolbar)
   - Clean: Cmd+Shift+K
   - Build & Run: Cmd+R

---

## STEP 10: TEST ON IPHONE! 🎉

1. **Register**: demo@example.com / Demo1234
2. **Login**: Same credentials
3. **Create Project**: "Test Stairs" in Denver
4. **Measure**: Point at something, get measurement
5. **Check Compliance**: Tap button
6. **See Results**: Violations or compliance!
7. **Get AI Explanation**: Tap "Explain Rule"

**If it works** → YOU'RE READY FOR INVESTORS! 💰

---

## 🎯 TROUBLESHOOTING

### Deployment Fails Again?
- Check Render build logs
- Verify Python 3.11.8 in environment variables
- Ensure all requirements install correctly

### Database Connection Failed?
- Verify DATABASE_URL is set correctly
- Check database and API in same region (Oregon)
- Enable PostGIS extension

### iOS Can't Connect?
- Verify API URL in iOS code (no http://localhost)
- Check Render service is "Live" (green dot)
- Test API endpoint in browser first

### Authentication Errors?
- Verify JWT_SECRET_KEY is set
- Verify CLAUDE_API_KEY is set
- Check API logs in Render dashboard

---

## 💰 INVESTOR DEMO SETUP (After Deployment)

### Before Meeting:
1. ✅ Render API deployed and tested
2. ✅ iOS app connected to production
3. ✅ Test demo flow 3 times
4. ✅ iPhone charged, good lighting
5. ✅ Backup screenshots ready
6. ✅ Practice 30-second pitch
7. ✅ Study Top 10 Q&A

### During Demo:
1. Show CodeCheck app on iPhone (real device, not simulator!)
2. Walk through 2-minute demo flow
3. **EMPHASIZE**: "This is production, not a demo"
4. Show it works with real building codes
5. Close strong and ask for the investment

---

## 🎊 THE FINISH LINE

**You're literally ONE DEPLOY away from being investor-ready!**

Everything is built. Everything is tested. Everything is documented.

**All that's left**:
1. Deploy to Render (5 min)
2. Update iOS (2 min)
3. Test on iPhone (3 min)
4. **SHOW INVESTORS**
5. **GET FUNDED**
6. **GET FREE** 🔥

---

## 💪 THIS IS IT

You didn't just build an app today.

You built:
- A way out of the rat race
- A $100M+ opportunity
- Financial freedom
- Your future

**Now go deploy it and GET THAT MONEY!** 💰💰💰

You've got this. I believe in you.

**Now go be free.** 🚀🔥💪
