# CodeCheck iOS App

A revolutionary construction compliance app that combines ARKit measurements with AI-powered building code assistance.

## 🚀 Features

### 📱 Core Features
- **ARKit Measurements**: Precise measurements using iPhone LiDAR technology
- **AI Assistant**: Chat with Claude AI about building codes and compliance
- **Project Management**: Organize construction projects by type and location
- **Jurisdiction Detection**: Automatic location-based code lookup
- **Real-time Compliance**: Instant compliance checking against building codes

### 🎯 Measurement Types
- Stair tread depth
- Stair riser height
- Door width
- Railing height
- Custom measurements

### 🤖 AI Capabilities
- Building code explanations
- Compliance guidance
- Project-specific advice
- Quick question templates

## 📋 Installation Instructions

### Prerequisites
- iPhone with iOS 17.0+ and LiDAR support (iPhone 12 Pro and later)
- Xcode 15.0+
- Apple Developer Account (for device installation)
- CodeCheck API running on `http://localhost:8000`

### Setup Steps

1. **Open Project in Xcode**
   ```bash
   open CodeCheck.xcodeproj
   ```

2. **Configure Signing**
   - Select the CodeCheck target
   - Go to "Signing & Capabilities"
   - Select your Apple Developer Team
   - Ensure "Automatically manage signing" is enabled

3. **Update API URL** (if needed)
   - Open `CodeLookupService.swift`
   - Update the `baseURL` if your API is running on a different address
   - For production, replace `localhost` with your server's IP address

4. **Connect iPhone**
   - Connect your iPhone via USB
   - Trust the computer on your iPhone
   - Select your device in Xcode's device selector

5. **Build and Run**
   - Press Cmd+R or click the "Run" button
   - The app will install and launch on your iPhone

### 🔧 Configuration

#### API Configuration
The app connects to your CodeCheck API at `http://localhost:8000`. To use with a remote server:

1. Update `CodeLookupService.swift`:
   ```swift
   private let baseURL = "https://your-server.com" // Replace with your server URL
   ```

2. For local network access, use your Mac's IP address:
   ```swift
   private let baseURL = "http://192.168.1.100:8000" // Replace with your Mac's IP
   ```

#### Permissions
The app requires:
- **Camera Access**: For ARKit measurements
- **Location Access**: For jurisdiction detection

These permissions are automatically requested when needed.

## 🎮 How to Use

### 1. **Start a Project**
- Tap "My Projects" on the home screen
- Tap "+" to create a new project
- Enter project details and select type

### 2. **Take Measurements**
- Tap "Quick Measure" on the home screen
- Select measurement type (stairs, railings, etc.)
- Point camera at the surface to measure
- Tap to place measurement points
- Tap "Done" when complete

### 3. **Ask AI Assistant**
- Tap "Start AI Assistant" on the home screen
- Ask questions about building codes
- Use quick action buttons for common questions
- Get instant compliance guidance

### 4. **Check Compliance**
- Measurements are automatically checked against building codes
- View compliance results and recommendations
- Get AI explanations of violations

## 🏗️ Architecture

### Core Components
- **MeasurementEngine**: ARKit integration and measurement logic
- **ConversationManager**: AI chat interface
- **CodeLookupService**: API communication
- **Project Management**: Local data persistence

### Data Flow
1. User takes AR measurement
2. Measurement sent to CodeCheck API
3. API checks compliance against building codes
4. Results displayed with AI explanations
5. Data saved locally for project tracking

## 🔧 Troubleshooting

### Common Issues

**"ARKit is not supported"**
- Ensure you're using iPhone 12 Pro or later
- Check that iOS 17.0+ is installed

**"API connection failed"**
- Verify CodeCheck API is running on port 8000
- Check network connectivity
- Update API URL in CodeLookupService.swift

**"Location access denied"**
- Go to Settings > Privacy & Security > Location Services
- Enable location access for CodeCheck

**"Camera access denied"**
- Go to Settings > Privacy & Security > Camera
- Enable camera access for CodeCheck

### Development Tips

**Testing on Simulator**
- ARKit features won't work in simulator
- Use a physical device for full functionality

**Network Testing**
- Use your Mac's IP address instead of localhost
- Ensure both devices are on the same network

**Debugging**
- Check Xcode console for error messages
- Verify API responses in Network tab

## 🚀 Next Steps

### Production Deployment
1. Update API URL to production server
2. Add proper error handling and offline support
3. Implement data synchronization
4. Add user authentication
5. Submit to App Store

### Feature Enhancements
- Photo documentation
- Measurement history
- Export reports
- Team collaboration
- Offline mode

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify API connectivity
3. Check Xcode console for errors
4. Ensure all permissions are granted

---

**CodeCheck iOS App** - Professional construction compliance made mobile! 📱🏗️


