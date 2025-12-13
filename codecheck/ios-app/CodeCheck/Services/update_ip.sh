#!/bin/bash

# CodeCheck IP Address Update Script
# This script helps you update the IP address in your iOS app files

echo "🔧 CodeCheck IP Address Updater"
echo "================================"
echo ""

# Get current IP address
echo "📍 Detecting your Mac's IP address..."
CURRENT_IP=$(ipconfig getifaddr en0 2>/dev/null)

if [ -z "$CURRENT_IP" ]; then
    echo "⚠️  Could not auto-detect IP address on en0"
    echo "   Trying alternative method..."
    CURRENT_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
fi

if [ -z "$CURRENT_IP" ]; then
    echo "❌ Could not detect IP address automatically"
    echo "   Please find your IP manually:"
    echo "   System Settings → Network → WiFi → IP Address"
    echo ""
    read -p "Enter your Mac's IP address: " CURRENT_IP
else
    echo "✅ Detected IP: $CURRENT_IP"
    echo ""
    read -p "Is this correct? (y/n): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        read -p "Enter your Mac's IP address: " CURRENT_IP
    fi
fi

echo ""
echo "🔄 Updating IP address to: $CURRENT_IP"
echo ""

# Find the project directory
PROJECT_DIR="."
if [ -d "CodeCheck" ]; then
    PROJECT_DIR="CodeCheck"
fi

# Files to update
AUTH_SERVICE="$PROJECT_DIR/Services/AuthService.swift"
CODE_LOOKUP="$PROJECT_DIR/Services/CodeLookupService.swift"

# Update AuthService.swift
if [ -f "$AUTH_SERVICE" ]; then
    echo "📝 Updating AuthService.swift..."
    # Use sed to replace the IP address
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|http://[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:8000|http://$CURRENT_IP:8000|g" "$AUTH_SERVICE"
    else
        # Linux
        sed -i "s|http://[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:8000|http://$CURRENT_IP:8000|g" "$AUTH_SERVICE"
    fi
    echo "   ✅ AuthService.swift updated"
else
    echo "   ⚠️  AuthService.swift not found at: $AUTH_SERVICE"
fi

# Update CodeLookupService.swift
if [ -f "$CODE_LOOKUP" ]; then
    echo "📝 Updating CodeLookupService.swift..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|http://[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:8000|http://$CURRENT_IP:8000|g" "$CODE_LOOKUP"
    else
        sed -i "s|http://[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*:8000|http://$CURRENT_IP:8000|g" "$CODE_LOOKUP"
    fi
    echo "   ✅ CodeLookupService.swift updated"
else
    echo "   ⚠️  CodeLookupService.swift not found at: $CODE_LOOKUP"
fi

echo ""
echo "✨ Done! IP address updated to: http://$CURRENT_IP:8000"
echo ""
echo "📱 Next steps:"
echo "   1. Clean build in Xcode (Cmd+Shift+K)"
echo "   2. Rebuild your app (Cmd+B)"
echo "   3. Run on your physical device"
echo "   4. Make sure your backend is running on port 8000"
echo "   5. Verify iPhone and Mac are on same WiFi network"
echo ""
echo "🧪 Test your backend:"
echo "   curl http://$CURRENT_IP:8000"
echo ""
