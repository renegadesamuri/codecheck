# Pre-Demo Technical Checklist

## ⚠️ Complete This 1 Hour Before Demo ⚠️

Print this out and check off each item as you complete it.

---

## Backend Preparation

### Start Backend API
```bash
cd /Users/raulherrera/autonomous-learning/codecheck/api
uvicorn main:app --host 0.0.0.0 --port 8001
```

- [ ] **Terminal 1**: Backend running (leave this terminal open)
- [ ] **Verify health**: `curl http://localhost:8001/` → Returns `{"status":"healthy"}`
- [ ] **Test login**: `curl -X POST http://localhost:8001/auth/login -H "Content-Type: application/json" -d '{"email":"test@codecheck.app","password":"Test1234"}'` → Returns access_token
- [ ] **Denver codes loaded**: Check backend logs show "15 rules loaded for Denver"

### Network Configuration
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

- [ ] **Mac IP verified**: 10.0.0.214 (or note new IP: _______________)
- [ ] **If IP changed**: Update iOS code and rebuild
  - [ ] Update `CodeLookupService.swift` line 9
  - [ ] Update `AuthService.swift` line 481
  - [ ] Update `Info.plist` NSExceptionDomains
- [ ] **Mac WiFi name**: _______________ (write down)
- [ ] **Mac connected to WiFi**: Visible in menu bar

---

## iPhone Preparation

### Physical Setup
- [ ] **iPhone model**: _______________ (must have LiDAR: iPhone 12 Pro or newer)
- [ ] **iOS version**: _______________ (must be 16.0+)
- [ ] **Battery level**: 100% (or 80%+ with charger ready)
- [ ] **Storage space**: At least 500MB free
- [ ] **Connected to Mac**: USB cable plugged in
- [ ] **Trust computer**: "Trust This Computer?" → Tap "Trust"

### iPhone Settings
- [ ] **WiFi**: Same network as Mac: _______________
- [ ] **Developer Mode**: Settings > Privacy & Security > Developer Mode → ON
- [ ] **Do Not Disturb**: Enabled (swipe down from top right, tap moon icon)
- [ ] **Brightness**: 80-100% (for AR and visibility)
- [ ] **Volume**: Muted (silent mode on)
- [ ] **Close other apps**: Double-tap home, swipe up to close all
- [ ] **Unlock phone**: Face ID or passcode entered

### App Permissions (Settings > CodeCheck)
- [ ] **Location**: "While Using App" or "Always"
- [ ] **Camera**: ON
- [ ] **Motion & Fitness**: ON (if present)
- [ ] **Cellular Data**: ON (as backup)

---

## Xcode Build

### Open & Configure
- [ ] **Launch Xcode**: Applications > Xcode.app
- [ ] **Open project**: File > Open > `/Users/raulherrera/autonomous-learning/codecheck/ios-app/CodeCheck.xcodeproj`
- [ ] **Select device**: Top toolbar > Select your iPhone (not simulator)
- [ ] **Team selected**: Project settings > Signing & Capabilities > Team: [Your Apple ID]
- [ ] **Automatically manage signing**: Checked

### Build & Install
- [ ] **Clean build**: Product > Clean Build Folder (Cmd+Shift+K)
- [ ] **Build**: Product > Build (Cmd+B)
- [ ] **Build succeeded**: Check Xcode status bar says "Build Succeeded"
- [ ] **No errors**: Issue Navigator (left sidebar) shows 0 errors
- [ ] **Run on device**: Product > Run (Cmd+R)
- [ ] **App installed**: CodeCheck icon visible on iPhone home screen
- [ ] **App launched**: Opens automatically to login/home screen

### Trust Developer Certificate (First Time Only)
**On iPhone**:
- [ ] Settings > General > VPN & Device Management
- [ ] Tap your Apple ID under "Developer App"
- [ ] Tap "Trust [Your Apple ID]"
- [ ] Confirm: Tap "Trust"

---

## App Testing

### Authentication
- [ ] **Open app**: Tap CodeCheck icon on iPhone
- [ ] **Login screen appears**: See email/password fields
- [ ] **Test login**: Email: `test@codecheck.app`, Password: `Test1234`
- [ ] **Login successful**: See home screen with "Welcome back!"
- [ ] **User profile loads**: Top right shows user initial or name

**If login fails**:
- Check backend is running on Mac
- Check iPhone on same WiFi as Mac
- Check Xcode console for errors

### Project Creation
- [ ] **Tap "New Project"**: Button visible and tappable
- [ ] **Project name**: Enter "Demo Project Denver"
- [ ] **Project type**: Select "Residential"
- [ ] **Location**: Auto-detects Denver, CO (or manually enter)
- [ ] **Create**: Tap "Create" button
- [ ] **Project created**: Returns to home, shows new project in list
- [ ] **Tap project**: Opens project detail view

**If project creation fails**:
- Check backend logs for errors
- Try manual location entry: "Denver, CO"

### AR Measurement
- [ ] **Tap "Measure"**: Opens measurement type selector
- [ ] **Select type**: Choose "Handrail Height" or "Door Width"
- [ ] **Camera opens**: See AR overlay on camera view
- [ ] **AR working**: Can see AR dots/measurements in real world
- [ ] **Place point**: Tap screen to place first AR point
- [ ] **Move camera**: Move to second point
- [ ] **Complete measurement**: Tap to place second point
- [ ] **Result shown**: Displays measurement in inches (e.g., "34 inches")

**If AR fails**:
- Check lighting (need bright room)
- Check camera permission
- Restart app
- Have backup: Show screenshots of AR measurement

### Compliance Checking
- [ ] **After measurement**: See "Check Compliance" button
- [ ] **Tap button**: Loading indicator appears
- [ ] **Results load**: Within 2-3 seconds
- [ ] **Compliance shown**: See pass/fail status
- [ ] **Details visible**: Shows specific code requirements
- [ ] **Violations clear**: If any, shows what's wrong and by how much

**If compliance check fails**:
- Check backend logs for errors
- Verify Denver codes loaded (should see 15 rules)
- Check network connection

### AI Explanation
- [ ] **Tap violation**: (if any violations shown)
- [ ] **Tap "Explain"**: Button visible
- [ ] **AI loads**: Loading indicator appears
- [ ] **Explanation shown**: Plain English explanation appears (3-5 seconds)
- [ ] **Content good**: Makes sense, explains code and fix

**If AI explanation fails**:
- Check backend has OpenAI/Anthropic API key configured
- May timeout if AI is slow - have backup explanation ready
- Can skip this in demo if needed

---

## Demo Rehearsal

### Run Through Full Demo (3x)
**Practice 1**: ⏱️ Time: _____
- [ ] Smooth? Y / N
- [ ] Under 2 minutes? Y / N
- [ ] Any issues: _______________

**Practice 2**: ⏱️ Time: _____
- [ ] Smooth? Y / N
- [ ] Under 2 minutes? Y / N
- [ ] Any issues: _______________

**Practice 3**: ⏱️ Time: _____
- [ ] Smooth? Y / N
- [ ] Under 2 minutes? Y / N
- [ ] Any issues: _______________

### Demo Flow Checklist
- [ ] **0:00-0:15**: Open app, explain problem
- [ ] **0:15-0:35**: Create project (show location auto-detect)
- [ ] **0:35-1:05**: AR measurement (point camera, place points)
- [ ] **1:05-1:35**: Check compliance (show results)
- [ ] **1:35-2:00**: AI explanation (show intelligence)
- [ ] **2:00-2:10**: Close with impact statement

---

## Backup Materials

### Have Ready (Just In Case)
- [ ] **Screenshots folder**: Created and loaded on iPhone or laptop
  - Login screen
  - Project creation
  - AR measurement in progress
  - Measurement result
  - Compliance check results
  - AI explanation
- [ ] **Demo video**: Pre-recorded perfect demo (2 minutes)
- [ ] **This checklist**: Printed or on laptop for quick reference
- [ ] **Investor demo guide**: Open on laptop
- [ ] **Xcode troubleshooting**: Know where to look for errors

### Emergency Contacts/Resources
- [ ] **Backend logs**: Know how to check (Terminal 1 on Mac)
- [ ] **Xcode console**: Know how to open (Cmd+Shift+Y)
- [ ] **Network tools**: Know how to check WiFi, IP address
- [ ] **Restart backend**: Know command to restart if needed
- [ ] **Rebuild app**: Know how to clean and rebuild (Cmd+Shift+K, Cmd+B)

---

## Environment Checklist

### Mac Setup
- [ ] **Laptop charged**: 100% or plugged in
- [ ] **Display mirroring ready**: If presenting on external screen
- [ ] **Terminal open**: Backend running and visible
- [ ] **Xcode open**: Project loaded, no errors
- [ ] **Notifications off**: Mac Do Not Disturb enabled
- [ ] **Other apps closed**: Only essential apps running
- [ ] **Desktop clean**: Professional appearance if screen sharing

### Presentation Area
- [ ] **Good lighting**: Bright room for AR to work
- [ ] **Measurement target**: Doorway, stairway, or railing ready
- [ ] **Stable surface**: For holding iPhone during AR measurement
- [ ] **Clear background**: No distracting items behind you
- [ ] **Internet backup**: Mobile hotspot ready if WiFi fails

---

## 5 Minutes Before Demo

### Final Verification
- [ ] **Backend status**: `curl http://localhost:8001/` → healthy
- [ ] **iPhone unlocked**: Face ID or passcode entered
- [ ] **App open**: On home screen, logged in
- [ ] **Battery check**: iPhone at 60%+ minimum
- [ ] **Network check**: Both on same WiFi: _______________
- [ ] **Rehearse pitch**: Say 30-second elevator pitch out loud
- [ ] **Deep breath**: You've got this!

### During Demo Protocol
- [ ] **Talk while doing**: Explain each step as you perform it
- [ ] **Show, don't tell**: Let app demonstrate features
- [ ] **Acknowledge loading**: "Just 2 seconds while it analyzes..."
- [ ] **Stay calm**: If error occurs, use backup materials
- [ ] **Engage audience**: Make eye contact, not just at phone
- [ ] **End strong**: "This is live right now - want to see it again?"

---

## Post-Demo Actions

### Immediate (While Investors Are Present)
- [ ] **Ask for questions**: "Any questions about what you just saw?"
- [ ] **Offer second demo**: "Want to see it measure something else?"
- [ ] **Get contact info**: Name, email, firm
- [ ] **Set follow-up**: "Can I send you our deck and schedule a call?"
- [ ] **Thank them**: "Thank you for your time and interest"

### Within 24 Hours
- [ ] **Send thank you email**: With deck, demo video, contact info
- [ ] **LinkedIn connect**: Add investors on LinkedIn with note
- [ ] **Update CRM**: Log meeting notes, next steps
- [ ] **Debrief**: Write down what went well, what to improve
- [ ] **Follow up**: Schedule next meeting if interest shown

---

## Troubleshooting During Demo

### Issue: Backend Not Responding
**Quick Fix**:
1. Check Terminal 1 - backend still running?
2. If not: `Ctrl+C`, then `uvicorn main:app --host 0.0.0.0 --port 8001`
3. Or: Use backup screenshots, explain "This is from a previous session"

### Issue: iPhone Not Connecting to Backend
**Quick Fix**:
1. Check iPhone WiFi: Same as Mac?
2. Check Mac IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
3. Or: Use backup video, explain "Let me show you a recorded demo"

### Issue: AR Not Working
**Quick Fix**:
1. Check lighting: Move to brighter area
2. Check camera permission: Settings > CodeCheck > Camera
3. Or: Use screenshots, explain "AR works best in good lighting"

### Issue: App Crashes
**Quick Fix**:
1. Force close app: Swipe up from home
2. Reopen app
3. Or: Use backup video/screenshots

### Issue: Investor Skeptical
**Quick Fix**:
1. Acknowledge concern: "That's a great question..."
2. Provide data: "750,000 contractors, $1.6T industry..."
3. Show traction: "We have 15 Denver codes loaded, expanding to 50 cities"
4. Offer proof: "Want to measure something specific?"

---

## Success Metrics

### Demo Was Successful If:
- [ ] Completed full flow without major issues
- [ ] Investor asked follow-up questions
- [ ] Investor requested meeting or materials
- [ ] Investor introduced you to someone else
- [ ] Investor seemed engaged (not checking phone)
- [ ] You felt confident and passionate

### Areas to Improve For Next Time:
1. _______________
2. _______________
3. _______________

---

## Confidence Reminders

**Before you start**:
- You've built a working product (most founders don't get this far)
- You've tested it multiple times (you know it works)
- You're solving a real problem ($1.6T market)
- Investors want you to succeed (they're looking for great founders)
- Technical hiccups are expected (they won't hold it against you)

**You've got this. Now go get funded!**

---

## Sign Off

Completed by: _______________ Date: _______________ Time: _______________

**All items checked?** [ ] YES → Ready for demo!

**Any issues?** [ ] NO → You're good to go!

**Feeling confident?** [ ] YES → You've got this!

---

**Now close this checklist, take a deep breath, and show them what CodeCheck can do.**

**Good luck! 🚀**
