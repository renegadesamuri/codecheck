# CodeCheck iOS App - Installation Guide

## ✅ What You Just Got

A complete, fully-functional iOS app with:
- ✨ ARKit/LiDAR measurement system
- 🤖 AI chat interface powered by Claude
- 📊 Project management with local data persistence
- 🗺️ Location-based jurisdiction detection
- ✅ Real-time compliance checking

## 📱 Requirements

### Device Requirements
- **iPhone 12 Pro or later** (requires LiDAR sensor)
- **iOS 17.0 or later**

### Development Requirements
- **macOS** with Xcode 15.0+
- **Apple Developer Account** (free or paid)
- **CodeCheck API running** (see Backend Setup below)

## 🚀 Installation Steps

### Step 1: Open the Project

```bash
cd /Users/raulherrera/autonomous-learning/codecheck/ios-app
open CodeCheck.xcodeproj
```

Xcode should open with the CodeCheck project loaded.

### Step 2: Configure Code Signing

1. In Xcode, select the **CodeCheck** project in the navigator
2. Select the **CodeCheck** target
3. Go to the **"Signing & Capabilities"** tab
4. Under "Signing", select your **Team** from the dropdown
   - If you don't see your team, add your Apple ID in Xcode Preferences
5. Ensure **"Automatically manage signing"** is checked
6. Xcode will automatically create a provisioning profile

### Step 3: Configure API Connection

**IMPORTANT:** The app needs to connect to your API server. By default, it's set to `localhost:8000`, which won't work from your iPhone.

1. Find your Mac's local IP address:
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   You'll see something like: `inet 192.168.1.123`

2. In Xcode, open: **CodeCheck/Services/CodeLookupService.swift**

3. Update line 8 to use your Mac's IP:
   ```swift
   private let baseURL = "http://192.168.1.123:8000"  // Replace with YOUR IP
   ```

4. Save the file (Cmd+S)

### Step 4: Connect Your iPhone

1. Connect your iPhone to your Mac via USB
2. Unlock your iPhone
3. If prompted, tap **"Trust This Computer"** on your iPhone
4. In Xcode's toolbar, click the device selector and choose your iPhone

### Step 5: Build and Run

1. Click the **Play button** (▶) or press **Cmd+R**
2. Xcode will build the app and install it on your iPhone
3. First time running, you may need to:
   - Go to **Settings → General → VPN & Device Management**
   - Tap your developer profile
   - Tap **"Trust [Your Name]"**

4. When the app launches, grant permissions:
   - **Camera Access**: Required for ARKit measurements
   - **Location Access**: Required for jurisdiction detection

## 🎯 First Launch

### What You'll See:
1. **Home Screen** with quick actions:
   - Quick Measure
   - AI Assistant
   - My Projects
   - Find Codes

2. **Tab Bar** at the bottom:
   - Home
   - Projects
   - AI Assistant

### Try These Features:

**Test ARKit Measurement:**
1. Tap "Quick Measure"
2. Select "Stair Tread" from the dropdown
3. Tap "Start Measuring"
4. Point at a flat surface
5. Tap to place two points
6. See the distance in inches!

**Chat with AI:**
1. Tap "AI Assistant" tab
2. Try: "What are the requirements for stairs?"
3. The AI will respond (if API is running)

**Create a Project:**
1. Tap "Projects" tab
2. Tap the "+" button
3. Fill in project details
4. Start adding measurements

## 🔧 Backend Setup

The iOS app needs the CodeCheck API server running to use AI features and compliance checking.

### Quick Start (Terminal):

```bash
# Navigate to API directory
cd /Users/raulherrera/autonomous-learning/codecheck/api

# Install dependencies (first time only)
pip install -r requirements.txt

# Start the server
uvicorn main:app --host 0.0.0.0 --port 8000
```

**Keep this terminal window open while using the app!**

### Verify API is Running:

```bash
curl http://localhost:8000/
```

You should see: `{"message":"CodeCheck API is running"}`

## 🐛 Troubleshooting

### Build Errors

**"Signing for 'CodeCheck' requires a development team"**
- Go to Signing & Capabilities
- Select your Apple ID team from dropdown
- If no team appears, add your Apple ID in Xcode Preferences

**"Failed to register bundle identifier"**
- Change the bundle identifier:
  - Select CodeCheck target → General tab
  - Change Bundle Identifier to something unique like: `com.yourname.codecheck`

**"Command CodeCodeGen failed with a nonzero exit code"**
- Clean build folder: Product → Clean Build Folder (Cmd+Shift+K)
- Quit and restart Xcode
- Try building again

### Runtime Errors

**"ARKit is not supported"**
- You must use an iPhone 12 Pro or later with LiDAR
- ARKit doesn't work in the iOS Simulator

**"API connection failed"**
- Check that API server is running: `curl http://YOUR_IP:8000/`
- Verify both iPhone and Mac are on the same WiFi network
- Check firewall isn't blocking port 8000
- Update CodeLookupService.swift with correct IP address

**"Location access denied"**
- Go to iPhone Settings → Privacy & Security → Location Services
- Find CodeCheck
- Select "While Using the App"

**"Camera access denied"**
- Go to iPhone Settings → Privacy & Security → Camera
- Enable access for CodeCheck

### Performance Issues

**Measurements are inaccurate:**
- Ensure good lighting
- Move slowly while scanning
- Hold iPhone steady when placing points
- Clean your camera lenses

**App crashes on launch:**
- Check Xcode console for errors
- Verify all files are included in target
- Try cleaning and rebuilding

## 📊 Project File Structure

```
CodeCheck.xcodeproj/          # Xcode project file
CodeCheck/
├── CodeCheckApp.swift         # App entry point
├── ContentView.swift          # Main tab view
├── Info.plist                 # App configuration & permissions
├── Assets.xcassets/           # Images and colors
├── Views/
│   ├── HomeView.swift         # Home screen
│   ├── MeasurementView.swift  # AR measurement interface
│   ├── ConversationView.swift # AI chat interface
│   └── ProjectsView.swift     # Project management
├── Services/
│   ├── MeasurementEngine.swift    # ARKit measurement logic
│   ├── ConversationManager.swift  # Chat management
│   ├── CodeLookupService.swift    # API communication
│   └── ProjectManager.swift       # Data persistence
└── Models/
    └── Models.swift           # Data models
```

## 🎓 Next Steps

1. **Customize the App:**
   - Change colors in Assets.xcassets
   - Modify measurement types in Models.swift
   - Add custom quick actions in HomeView.swift

2. **Set up Backend:**
   - Follow the database setup in `/codecheck/database/`
   - Configure environment variables in `.env`
   - Start all backend services

3. **Test Full Features:**
   - Create a project
   - Take measurements
   - Check compliance
   - Chat with AI assistant

4. **Prepare for Distribution:**
   - Add app icon (1024x1024 PNG)
   - Update Info.plist with privacy descriptions
   - Create screenshots for App Store
   - Set up TestFlight for beta testing

## 📞 Need Help?

- **Build Issues**: Check Xcode's Issue Navigator (Cmd+5)
- **Runtime Issues**: Check Xcode Console while app is running
- **API Issues**: Check API server logs in terminal
- **General Help**: See main README.md in project root

## 🎉 Success!

If you've made it this far and the app is running on your iPhone:
- ✅ You have a fully functional construction compliance app
- ✅ ARKit measurements with LiDAR technology
- ✅ AI-powered building code assistant
- ✅ Professional project management system

**Enjoy building with CodeCheck!** 📱🏗️✨
