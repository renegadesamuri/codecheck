# Autonomous Learning Platform

A comprehensive AI-powered learning platform featuring CodeCheck - an innovative construction compliance assistant for iOS.

## 🚀 Main Project: CodeCheck

**CodeCheck** is a revolutionary iOS app that combines ARKit/LiDAR measurements with AI-powered building code assistance to help construction professionals ensure compliance with local building codes.

### 📱 Key Features

- **ARKit Measurements**: Precise measurements using iPhone LiDAR technology
- **AI Assistant**: Chat with Claude AI about building codes and compliance
- **Project Management**: Organize construction projects by type and location
- **Jurisdiction Detection**: Automatic location-based code lookup
- **Real-time Compliance**: Instant compliance checking against building codes

### 🏗️ Project Structure

```
codecheck/
├── api/                    # FastAPI Backend
│   ├── main.py            # Main API server
│   ├── claude_service.py  # Claude AI integration
│   └── requirements.txt   # Python dependencies
├── ios-app/               # iOS Application
│   ├── CodeCheck.xcodeproj  # Xcode project
│   └── CodeCheck/         # Swift source code
│       ├── Views/         # SwiftUI views
│       ├── Services/      # Business logic
│       └── Models/        # Data models
├── web-frontend/          # Web Interface
│   └── index.html        # Modern web frontend
├── database/             # Database Setup
│   ├── schema.sql        # PostgreSQL schema
│   └── setup.py          # Database utilities
└── agents/               # AI Agents
    ├── claude_integration.py
    ├── rule_extractor.py
    └── jurisdiction_finder.py
```

## 🎯 Quick Start

### Prerequisites
- **For iOS Development:**
  - iPhone with iOS 17.0+ and LiDAR (iPhone 12 Pro or later)
  - Xcode 15.0+
  - Apple Developer Account

- **For Backend:**
  - Python 3.11+
  - PostgreSQL with PostGIS
  - Claude API key

### iOS App Installation

1. **Open the Xcode Project**
   ```bash
   cd codecheck/ios-app
   open CodeCheck.xcodeproj
   ```

2. **Configure Code Signing**
   - Select the CodeCheck target in Xcode
   - Go to "Signing & Capabilities"
   - Select your Apple Developer Team
   - Ensure "Automatically manage signing" is enabled

3. **Update API Configuration**
   - Open `CodeCheck/Services/CodeLookupService.swift`
   - Update the `baseURL` with your API server address:
     ```swift
     private let baseURL = "http://YOUR_MAC_IP:8000"
     ```
   - For local development, use your Mac's local network IP

4. **Connect Your iPhone**
   - Connect via USB
   - Trust the computer on your iPhone
   - Select your device in Xcode

5. **Build and Run**
   - Press Cmd+R or click the "Run" button
   - Grant camera and location permissions when prompted

### Backend Setup

1. **Set up Environment**
   ```bash
   cd codecheck
   cp .env.example .env
   # Edit .env and add your Claude API key
   ```

2. **Start Database**
   ```bash
   docker-compose up postgres -d
   cd database
   pip install -r requirements.txt
   python setup.py
   ```

3. **Start API Server**
   ```bash
   cd api
   pip install -r requirements.txt
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```

4. **Test API**
   ```bash
   curl http://localhost:8000/
   ```

## 📱 Using the iOS App

### Quick Measurement
1. Tap "Quick Measure" on the home screen
2. Select measurement type (stairs, railings, doors, etc.)
3. Point camera at the surface
4. Tap to place measurement points
5. View results and check compliance

### AI Assistant
1. Tap "AI Assistant" on the home screen
2. Ask questions about building codes
3. Use quick action buttons for common questions
4. Get instant AI-powered guidance

### Project Management
1. Tap "My Projects" to view all projects
2. Create a new project with location details
3. Add measurements to projects
4. Track compliance across all measurements

## 🔧 Configuration

### Network Setup for Local Testing

To use the app on your iPhone with the API running on your Mac:

1. **Find your Mac's IP address:**
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

2. **Update CodeLookupService.swift:**
   ```swift
   private let baseURL = "http://192.168.1.XXX:8000"  // Your Mac's IP
   ```

3. **Ensure both devices are on the same WiFi network**

### Required Permissions

The app will automatically request:
- **Camera Access**: For ARKit measurements
- **Location Access**: For jurisdiction detection

These are configured in `Info.plist` with user-friendly descriptions.

## 🛠️ Technology Stack

### iOS App
- **SwiftUI**: Modern declarative UI framework
- **ARKit + RealityKit**: AR measurements with LiDAR
- **CoreLocation**: Location-based services
- **Combine**: Reactive programming

### Backend
- **FastAPI**: High-performance Python API
- **PostgreSQL + PostGIS**: Spatial database
- **Claude AI**: Natural language processing
- **Docker**: Containerization

## 📝 API Endpoints

- `POST /resolve` - Resolve coordinates to jurisdictions
- `POST /check` - Check compliance against measurements
- `POST /conversation` - AI chat interface
- `GET /jurisdictions` - Get available jurisdictions

## 🚀 Development Status

- [x] iOS app with ARKit measurements
- [x] SwiftUI interface with modern design
- [x] AI chat integration
- [x] Project management system
- [x] API backend with FastAPI
- [x] Database schema
- [ ] Production deployment
- [ ] App Store submission
- [ ] Multi-user synchronization

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is proprietary software. All rights reserved.

## 📞 Support

### Common Issues

**"ARKit is not supported"**
- Ensure you're using iPhone 12 Pro or later with LiDAR
- Check that iOS 17.0+ is installed

**"API connection failed"**
- Verify API is running: `curl http://YOUR_IP:8000/`
- Check that both devices are on same network
- Update `baseURL` in CodeLookupService.swift

**"Build failed in Xcode"**
- Clean build folder: Product → Clean Build Folder
- Ensure all files are included in target
- Check code signing configuration

### Getting Help

- Check the [iOS App README](codecheck/ios-app/README.md) for detailed instructions
- Review the [API README](codecheck/README.md) for backend setup
- Create an issue for bugs or questions

---

**CodeCheck** - Professional construction compliance made mobile! 📱🏗️
