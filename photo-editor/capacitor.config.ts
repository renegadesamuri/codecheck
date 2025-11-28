import type { CapacitorConfig } from '@capacitor/cli';

/**
 * Capacitor Configuration
 *
 * Server configuration allows the app to connect to a development backend.
 * In development, this enables HTTP connections to localhost or network IP.
 */

const config: CapacitorConfig = {
  appId: 'com.codecheck.photoeditor',
  appName: 'Photo Editor Pro',
  webDir: 'dist',

  // Server configuration for development
  // This allows the iOS app to connect to your local backend
  server: {
    // Use environment variable or default to localhost
    // The app will auto-detect the correct URL on startup
    url: process.env.VITE_API_BASE_URL,

    // Allow HTTP (non-HTTPS) connections in development
    cleartext: true,

    // Allow connections from the app
    androidScheme: 'http'
  },

  // iOS-specific configuration
  ios: {
    // Allow HTTP connections (required for local development)
    contentInset: 'automatic',
  },

  // Android-specific configuration
  android: {
    // Allow HTTP connections
    allowMixedContent: true,
  }
};

export default config;
