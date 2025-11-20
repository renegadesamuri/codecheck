# Xcode Build Instructions - CodeCheck iOS App

## Prerequisites

### Software Requirements
- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later (download from Mac App Store)
- **iOS Device**: iPhone with A12 Bionic chip or later (iPhone XS and newer)
- **iOS Version**: 16.0 or later on device
- **Developer Account**: Free Apple Developer account (for device testing)

### Hardware Requirements
- **Mac**: Any Mac that can run Xcode 15
- **iPhone**: Must have LiDAR sensor for AR features
  - iPhone 12 Pro / Pro Max
  - iPhone 13 Pro / Pro Max
  - iPhone 14 Pro / Pro Max
  - iPhone 15 Pro / Pro Max
  - iPad Pro (2020 or later)

### Network Requirements
- Mac and iPhone on **same WiFi network**
- Backend API running at: `http://10.0.0.214:8001`
- Internet connection for initial build (downloads dependencies)

---

## Step 1: Open Project in Xcode

### 1.1 Launch Xcode
```bash
# Option 1: From Finder
# Navigate to: /Applications/Xcode.app
# Double-click to launch

# Option 2: From Terminal
open -a Xcode

# Option 3: From Spotlight
# Press Cmd+Space, type "Xcode", press Enter
```

### 1.2 Open CodeCheck Project
```bash
# From Terminal
cd /Users/raulherrera/autonomous-learning/codecheck/ios-app
open CodeCheck.xcodeproj
```

**Or in Xcode**:
- File > Open...
- Navigate to: `/Users/raulherrera/autonomous-learning/codecheck/ios-app/`
- Select `CodeCheck.xcodeproj`
- Click "Open"

---

## Step 2: Configure Code Signing

### 2.1 Select Your Team
1. In Xcode, click on **CodeCheck** (blue project icon) in left sidebar
2. Under "TARGETS", select **CodeCheck**
3. Click **"Signing & Capabilities"** tab
4. Under "Signing", check **"Automatically manage signing"**
5. Select your **Team** from dropdown
   - If you don't have a team, click "Add Account..." and sign in with your Apple ID
   - Free accounts work for device testing (7-day certificates)

### 2.2 Update Bundle Identifier (If Needed)
If you get signing errors:
1. Change **Bundle Identifier** from `com.codecheck.app` to something unique
2. Example: `com.yourname.codecheck`
3. Xcode will automatically provision certificates

### 2.3 Trust Your Developer Certificate on iPhone
**On your iPhone**:
1. Go to **Settings > General > VPN & Device Management**
2. Find your Apple ID under "Developer App"
3. Tap it and select **"Trust [Your Apple ID]"**
4. Confirm by tapping "Trust"

---

## Step 3: Connect iPhone

### 3.1 Physical Connection
1. Connect iPhone to Mac using **USB-C to Lightning cable** (or USB-C to USB-C for newer iPhones)
2. **Unlock iPhone** - Face ID or passcode
3. If prompted "Trust This Computer?", tap **"Trust"**
4. Enter iPhone passcode if requested

### 3.2 Verify Connection in Xcode
1. In Xcode toolbar (top), look for device selector
2. Click the device dropdown (next to "CodeCheck" scheme)
3. Under "iOS Device", you should see your iPhone's name
4. Select your iPhone

**If iPhone doesn't appear**:
- Unplug and replug the cable
- Restart Xcode
- Ensure iPhone is unlocked
- Check cable is data-capable (not charge-only)

---

## Step 4: Enable Developer Mode on iPhone

**iOS 16 and later require Developer Mode for app installation**

### 4.1 Enable Developer Mode
**On your iPhone**:
1. Go to **Settings**
2. Scroll down to **Privacy & Security**
3. Scroll to bottom and tap **Developer Mode**
4. Toggle **Developer Mode ON**
5. Tap **"Restart"** when prompted
6. After restart, confirm by tapping **"Turn On"** in alert

**Note**: If you don't see "Developer Mode", your iOS might be older than 16.0. Update iOS first.

---

## Step 5: Build and Run

### 5.1 Select Build Configuration
1. In Xcode, select your iPhone from device selector (top toolbar)
2. Ensure scheme is set to **"CodeCheck"** (next to device selector)
3. Select **Product > Scheme > Edit Scheme...**
4. Under "Run", set **Build Configuration** to "Debug"
5. Click "Close"

### 5.2 Build the App
**Option 1: Build Only** (recommended for first time)
```
Product > Build
Or press: Cmd + B
```
- Watch for any build errors in Xcode console (bottom panel)
- If errors occur, see Troubleshooting section below

**Option 2: Build and Run**
```
Product > Run
Or press: Cmd + R
Or click the Play (▶) button in toolbar
```

### 5.3 First Build Checklist
- [ ] Xcode shows "Build Succeeded" in status bar
- [ ] No red errors in Issue Navigator (left sidebar, triangle icon)
- [ ] App installs on iPhone (you'll see CodeCheck icon)
- [ ] App launches automatically

**Build Time**: First build takes 2-5 minutes (subsequent builds: 30 seconds)

---

## Step 6: Grant Permissions on iPhone

### 6.1 Allow Camera Access
When app first launches, you'll see permission requests:

1. **Camera Permission**: "CodeCheck Would Like to Access the Camera"
   - Tap **"Allow"**
   - Required for AR measurement

2. **Location Permission**: "Allow CodeCheck to access your location?"
   - Tap **"Allow While Using App"**
   - Required for jurisdiction detection

3. **Motion & Fitness**: May be requested for AR features
   - Tap **"Allow"** if prompted

### 6.2 Verify Permissions (If Denied)
If you accidentally denied permissions:
1. On iPhone: **Settings > CodeCheck**
2. Enable:
   - **Location**: "While Using App"
   - **Camera**: ON
   - **Motion & Fitness**: ON (if available)
3. Restart app

---

## Step 7: Connect to Backend

### 7.1 Verify Backend is Running
**On your Mac** (before launching app):
```bash
# Check backend status
curl http://localhost:8001/

# Should return: {"status":"healthy"}

# If not running, start it:
cd /Users/raulherrera/autonomous-learning/codecheck/api
uvicorn main:app --host 0.0.0.0 --port 8001
```

### 7.2 Verify Network Configuration
```bash
# Confirm Mac IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

# Should show: inet 10.0.0.214 ...
```

**If IP changed**: Update these files and rebuild:
- `/Users/raulherrera/autonomous-learning/codecheck/ios-app/CodeCheck/Services/CodeLookupService.swift` (line 9)
- `/Users/raulherrera/autonomous-learning/codecheck/ios-app/CodeCheck/Services/AuthService.swift` (line 481)
- `/Users/raulherrera/autonomous-learning/codecheck/ios-app/CodeCheck/Info.plist` (add new IP to NSExceptionDomains)

### 7.3 Test Connection
**In the app on iPhone**:
1. On login screen, tap **"Register"** (or use existing test account)
2. Test Account:
   - Email: `test@codecheck.app`
   - Password: `Test1234`
3. Tap **"Login"**

**Success**: You should see home screen with "Welcome back!"
**Failure**: See "Network error" → Check backend and network configuration

---

## Step 8: Test Core Features

### 8.1 Authentication
- [ ] Login with test account works
- [ ] Register new account works
- [ ] Biometric login works (if enabled)

### 8.2 Project Creation
- [ ] Tap "New Project"
- [ ] Enter project name: "Test Denver Project"
- [ ] Select project type: "Residential"
- [ ] Location auto-detects (or manually enter "Denver, CO")
- [ ] Tap "Create" → should see project in list

### 8.3 AR Measurement
- [ ] Open project
- [ ] Tap "Measure"
- [ ] Select measurement type: "Handrail Height"
- [ ] Camera opens with AR overlay
- [ ] Can place AR points and measure

### 8.4 Compliance Checking
- [ ] After measurement, tap "Check Compliance"
- [ ] Results appear within 2-3 seconds
- [ ] See pass/fail status
- [ ] Violations show specific requirements

### 8.5 AI Explanation
- [ ] Tap on any violation
- [ ] Tap "Explain This Rule"
- [ ] AI explanation loads (takes 3-5 seconds)
- [ ] Plain English explanation appears

---

## Troubleshooting

### Build Errors

#### Error: "No code signing identities found"
**Solution**:
1. Xcode > Settings > Accounts
2. Click "+" to add Apple ID
3. Sign in with your Apple ID
4. Select your team in project settings

#### Error: "Could not find developer disk image"
**Solution**:
- Your iPhone iOS version is newer than Xcode supports
- Update Xcode to latest version (Mac App Store)
- Or update iPhone to match Xcode version

#### Error: "The application could not be verified"
**Solution**:
- On iPhone: Settings > General > VPN & Device Management
- Trust your developer certificate

#### Error: Build fails with "Module not found"
**Solution**:
- Clean build folder: Product > Clean Build Folder (Cmd+Shift+K)
- Close Xcode and delete derived data:
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData
  ```
- Reopen project and rebuild

### Network Errors

#### Error: "Network error: Could not connect to server"
**Causes & Solutions**:

1. **Backend not running**:
   ```bash
   cd /Users/raulherrera/autonomous-learning/codecheck/api
   uvicorn main:app --host 0.0.0.0 --port 8001
   ```

2. **Wrong IP address configured**:
   ```bash
   # Get current IP
   ifconfig | grep "inet " | grep -v 127.0.0.1

   # Update files with new IP:
   # - CodeLookupService.swift (line 9)
   # - AuthService.swift (line 481)
   # - Info.plist (NSExceptionDomains)
   ```

3. **Different WiFi networks**:
   - Ensure Mac and iPhone on same WiFi network
   - Check Mac WiFi: Click WiFi icon in menu bar
   - Check iPhone WiFi: Settings > WiFi

4. **Firewall blocking**:
   ```bash
   # Allow port 8001 through firewall
   # Mac: System Settings > Network > Firewall > Options
   # Add port 8001 to allowed incoming connections
   ```

#### Error: "SSL error" or "Invalid certificate"
**Solution**:
- Verify Info.plist allows HTTP for your Mac's IP
- Check NSAppTransportSecurity > NSExceptionDomains
- Should include entry for `10.0.0.214` with `NSExceptionAllowsInsecureHTTPLoads = true`

### AR / Camera Errors

#### Error: "Camera not available"
**Solution**:
- Settings > CodeCheck > Camera → Enable
- Restart app

#### Error: "ARKit session failed"
**Solution**:
- Ensure device has LiDAR (iPhone 12 Pro or newer)
- Check Info.plist has `arkit` in UIRequiredDeviceCapabilities
- Restart iPhone if AR session is stuck

#### Error: "Poor lighting conditions"
**Solution**:
- Move to area with better lighting
- AR requires good ambient light
- Avoid backlighting (windows behind target)

### Runtime Errors

#### App crashes on launch
**Solution**:
1. Check Xcode console for crash logs (bottom panel)
2. Look for red error messages
3. Common causes:
   - Missing permissions in Info.plist
   - Backend API not reachable
   - Invalid token in keychain (clear app data)

**Clear app data**:
- On iPhone: Delete app and reinstall
- Or in Xcode: Window > Devices and Simulators > Select iPhone > Installed Apps > CodeCheck > gear icon > Delete App Data

#### App hangs on "Loading..."
**Solution**:
- Backend API is slow or not responding
- Check backend logs on Mac
- Restart backend API
- Force quit app and relaunch

---

## Performance Optimization

### For Demo Day

1. **Disable Debug Logging**:
   - Product > Scheme > Edit Scheme > Run > Arguments
   - Remove any debug launch arguments

2. **Use Release Build** (for final demos):
   - Product > Scheme > Edit Scheme > Run
   - Build Configuration: **Release**
   - Note: First release build takes longer

3. **Pre-load Data**:
   - Before demo, open app and log in
   - Create test project for Denver
   - Loads codes in background
   - Subsequent demos will be faster

4. **Optimize iPhone**:
   - Close all other apps
   - Enable Do Not Disturb
   - Set brightness to 80-100%
   - Ensure 50%+ battery

---

## Building for Distribution (Future)

### TestFlight (Internal Testing)
**Requirements**:
- Paid Apple Developer account ($99/year)
- App Store Connect setup

**Steps**:
1. Archive app: Product > Archive
2. Upload to App Store Connect
3. Add internal testers
4. Distribute via TestFlight

### App Store Release
**Requirements**:
- Paid Apple Developer account
- Privacy policy URL
- App Store screenshots and description
- Review process (7-14 days)

**Not needed for investor demos** - device testing is sufficient

---

## Quick Reference

### Common Xcode Shortcuts
- **Build**: Cmd + B
- **Run**: Cmd + R
- **Stop**: Cmd + .
- **Clean Build**: Cmd + Shift + K
- **Show/Hide Console**: Cmd + Shift + Y
- **Show/Hide Navigator**: Cmd + 0
- **Find in Project**: Cmd + Shift + F

### Common Terminal Commands
```bash
# Start backend
cd /Users/raulherrera/autonomous-learning/codecheck/api
uvicorn main:app --host 0.0.0.0 --port 8001

# Check backend health
curl http://localhost:8001/

# Get Mac IP
ifconfig | grep "inet " | grep -v 127.0.0.1

# View backend logs (in separate terminal)
cd /Users/raulherrera/autonomous-learning/codecheck/api
tail -f server.log  # if logging to file
```

### Key File Locations
```
iOS App: /Users/raulherrera/autonomous-learning/codecheck/ios-app/
Backend API: /Users/raulherrera/autonomous-learning/codecheck/api/
Demo Guide: /Users/raulherrera/autonomous-learning/codecheck/ios-app/INVESTOR_DEMO_GUIDE.md
This Guide: /Users/raulherrera/autonomous-learning/codecheck/ios-app/XCODE_BUILD_INSTRUCTIONS.md
```

### Test Credentials
```
Email: test@codecheck.app
Password: Test1234
Location: Denver, CO (15 codes loaded)
```

### Network Configuration
```
Backend URL: http://10.0.0.214:8001
Mac IP: 10.0.0.214
Port: 8001
Protocol: HTTP (local dev only)
```

---

## Pre-Demo Checklist

**1 Hour Before**:
- [ ] Mac and iPhone on same WiFi
- [ ] Backend running: `curl http://localhost:8001/` returns healthy
- [ ] iPhone charged to 100%
- [ ] Xcode project opens without errors
- [ ] Clean build succeeds: Cmd + Shift + K, then Cmd + B
- [ ] App installs and runs on iPhone
- [ ] Can login with test@codecheck.app
- [ ] Can create project in Denver
- [ ] Can measure something with AR
- [ ] Can check compliance and see results
- [ ] Practiced full demo flow 2-3 times

**If ANY step fails, troubleshoot NOW - not during demo!**

---

## Emergency Backup Plan

### If Build Fails During Demo
1. **Have pre-recorded video** ready:
   - Record successful demo beforehand
   - Load on iPhone or laptop
   - Play video if live demo fails

2. **Use simulator** (if iPhone fails):
   - Select "iPhone 15 Pro" in Xcode device selector
   - Simulator doesn't have AR, but can show UI
   - Explain: "This is the simulator version, but on device it has AR"

3. **Show screenshots**:
   - Take screenshots of each demo step beforehand
   - Load in Photos app on iPhone
   - Swipe through as backup

### If Network Fails During Demo
1. **Use mock data mode**:
   - Could implement offline mode with cached results
   - For now: Show pre-recorded results

2. **Tether to phone hotspot**:
   - Enable Personal Hotspot on iPhone
   - Connect Mac to iPhone hotspot
   - Get new Mac IP and update app (last resort)

---

## Getting Help

### During Development
- **Xcode Issues**: Help > Developer Documentation
- **Swift Language**: swiftdoc.org
- **ARKit**: developer.apple.com/arkit
- **Stack Overflow**: stackoverflow.com/questions/tagged/swift

### During Demo
- **Keep this guide open** on Mac for quick reference
- **Have terminal with backend logs** visible (Cmd+Tab to check)
- **Know the troubleshooting section** by heart
- **Stay calm** - investors expect some technical hiccups

---

## Success Criteria

### You're Ready for Demo When:
- [ ] App builds without errors
- [ ] App runs on physical iPhone (not just simulator)
- [ ] Can complete full demo flow in under 2 minutes
- [ ] All features work (login, project, measure, check, explain)
- [ ] Network connection is stable
- [ ] Have tested 3 times in past hour
- [ ] Backup plan ready (screenshots, video)
- [ ] Confident with Xcode and device setup

---

## Final Notes

**Building an iOS app is complex - don't panic if something breaks.**

The most important things:
1. Start early - don't wait until 10 minutes before demo
2. Test on the actual iPhone you'll use for demo
3. Have backup plan ready (screenshots, video)
4. Practice the demo until you can do it with eyes closed
5. Stay calm if something fails - investors understand technical difficulties

**You've got a working app. You've got a great backend. You've got a massive market.**

**Now go show them what CodeCheck can do.**

**Good luck!**
