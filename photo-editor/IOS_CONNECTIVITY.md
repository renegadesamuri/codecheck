# iOS Connectivity Guide

This document explains how the iOS app connects to the CodeCheck backend and how to troubleshoot connection issues.

## How It Works

The app automatically detects its environment and configures the correct API URL:

### Browser Development
- **URL:** Relative paths (e.g., `/api/analyze/image`)
- **How:** Vite dev server proxies requests to `localhost:8000`
- **Config:** No configuration needed

### iOS Simulator
- **URL:** `http://localhost:8000`
- **How:** Simulator shares localhost with your Mac
- **Config:** Automatic on app startup

### iOS Device (Real iPhone/iPad)
- **URL:** `http://192.168.1.X:8000` (your Mac's network IP)
- **How:** App fetches network info from backend
- **Config:** Automatic on app startup

## Automatic Configuration

The app calls `initializeApp()` on startup, which:

1. Detects if running in Capacitor (native app)
2. Fetches network info from backend at `/api/connectivity/network-info`
3. Saves the correct API URL to localStorage
4. Tests the connection
5. Reports success/failure in console

## Setup for iOS Development

### 1. Start the Backend

```bash
cd codecheck/api
python3 main.py
```

The backend will report its network IP:
```
✅ Database connection healthy (12ms)
✅ Redis connection healthy (2ms)
🚀 CodeCheck API ready on http://192.168.1.100:8000
```

### 2. Build and Run iOS App

```bash
cd photo-editor
npm run build
npx cap sync
npx cap open ios
```

### 3. Check Console Logs

In Xcode, check the console for:
```
🚀 Initializing CodeCheck app...
✅ API URL configured: http://192.168.1.100:8000
✅ Backend connection successful
```

## Troubleshooting

### Problem: "Backend not reachable" on Real Device

**Symptoms:**
- Works in simulator
- Fails on real iPhone/iPad
- Console shows: `⚠️  Backend not reachable`

**Solutions:**

1. **Check Same Network**
   - Ensure your iPhone and Mac are on the same Wi-Fi network
   - Check Wi-Fi settings on both devices

2. **Check Firewall**
   ```bash
   # On Mac, allow incoming connections for Python
   # System Preferences → Security & Privacy → Firewall → Firewall Options
   # Allow: Python
   ```

3. **Test Backend URL Manually**
   ```bash
   # Get your Mac's IP
   ifconfig | grep "inet " | grep -v 127.0.0.1

   # Test from iPhone Safari
   # Open: http://YOUR_IP:8000/api/connectivity/health
   ```

4. **Force Reconfigure**
   ```javascript
   // In Safari on iPhone, open console and run:
   localStorage.removeItem('api_base_url');
   location.reload();
   ```

### Problem: "CORS Error" in Console

**Solution:**
Check backend CORS configuration includes your frontend URL:

```bash
# In codecheck/api/.env
ALLOWED_ORIGINS=http://localhost:3000,http://192.168.1.100:3000
```

### Problem: "Connection Refused" on Simulator

**Solution:**
Ensure backend is running on localhost:8000:

```bash
lsof -i :8000
# Should show Python process
```

### Problem: Mixed Content Warning

**Symptom:**
Browser blocks HTTP requests when served over HTTPS

**Solution:**
Capacitor is configured to allow HTTP in development:
- `cleartext: true` in capacitor.config.ts
- `allowMixedContent: true` for Android

## Manual Configuration

If automatic configuration fails, you can manually set the API URL:

### Option 1: Environment Variable

```bash
# Create .env.local in photo-editor/
echo "VITE_API_BASE_URL=http://192.168.1.100:8000" > .env.local

# Rebuild
npm run build
npx cap sync
```

### Option 2: localStorage

```javascript
// In app or browser console:
localStorage.setItem('api_base_url', 'http://192.168.1.100:8000');
```

### Option 3: Hardcode (not recommended)

Edit `photo-editor/src/api/client.ts`:
```typescript
function getApiBaseUrl(): string {
  // Temporary hardcode
  return 'http://192.168.1.100:8000';
}
```

## Testing Connectivity

### From Browser
```javascript
import { testConnection, getApiConfig } from './api/client';

// Test connection
const connected = await testConnection();
console.log('Connected:', connected);

// View config
console.log(getApiConfig());
```

### From iOS App
Open Safari on iPhone → Develop → [Your iPhone] → [App Name] → Console

```javascript
// Test backend
fetch('http://192.168.1.100:8000/api/connectivity/health')
  .then(r => r.json())
  .then(console.log)
  .catch(console.error);
```

## Network Info Endpoint

The backend exposes a special endpoint for clients to discover its network address:

```bash
curl http://localhost:8000/api/connectivity/network-info
```

Response:
```json
{
  "local_ip": "192.168.1.100",
  "api_base_url": "http://192.168.1.100:8000",
  "localhost_url": "http://localhost:8000",
  "port": 8000,
  "environment": "development"
}
```

## Production Configuration

For production deployment:

1. Set backend URL in environment:
   ```bash
   VITE_API_BASE_URL=https://api.codecheck.app
   ```

2. Use HTTPS (not HTTP)

3. Remove `cleartext: true` from Capacitor config

4. Configure proper SSL certificates

## Debugging Commands

```bash
# Check what port backend is on
lsof -i :8000

# Get your Mac's IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# Test backend from command line
curl http://localhost:8000/api/connectivity/health

# Test from specific IP
curl http://192.168.1.100:8000/api/connectivity/health

# Check iOS app logs
# Xcode → Window → Devices and Simulators → [Your Device] → Console
```

## Additional Resources

- [Capacitor iOS Documentation](https://capacitorjs.com/docs/ios)
- [Capacitor Server Configuration](https://capacitorjs.com/docs/config#server)
- [FastAPI CORS Documentation](https://fastapi.tiangolo.com/tutorial/cors/)
