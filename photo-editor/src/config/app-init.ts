/**
 * App Initialization
 *
 * Handles startup configuration for the CodeCheck Photo Editor.
 * Must be called before the app starts making API requests.
 */

import { configureApiUrl, testConnection, getApiConfig } from '../api/client';

/**
 * Initialize the application
 *
 * Call this function when the app starts (e.g., in App.tsx useEffect)
 * to configure the API connection.
 *
 * Returns connection status and configuration info.
 */
export async function initializeApp(): Promise<{
  success: boolean;
  apiUrl: string;
  connected: boolean;
  config: any;
  error?: string;
}> {
  try {
    console.log('🚀 Initializing CodeCheck app...');

    // Step 1: Configure the API URL based on environment
    const apiUrl = await configureApiUrl();
    console.log(`✅ API URL configured: ${apiUrl}`);

    // Step 2: Test the connection
    const connected = await testConnection();

    if (connected) {
      console.log('✅ Backend connection successful');
    } else {
      console.warn('⚠️  Backend not reachable (this is normal if backend is not running)');
    }

    // Step 3: Get current configuration
    const config = getApiConfig();
    console.log('📊 API Config:', config);

    return {
      success: true,
      apiUrl,
      connected,
      config,
    };
  } catch (error) {
    console.error('❌ App initialization failed:', error);

    return {
      success: false,
      apiUrl: '',
      connected: false,
      config: getApiConfig(),
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Check if the backend is available
 *
 * Can be called periodically to monitor backend availability
 */
export async function checkBackendHealth(): Promise<boolean> {
  try {
    return await testConnection();
  } catch (error) {
    console.error('Backend health check failed:', error);
    return false;
  }
}

/**
 * Display connection info for debugging
 */
export function displayConnectionInfo(): void {
  const config = getApiConfig();

  console.group('🔍 CodeCheck Connection Info');
  console.log('Environment:', config.environment);
  console.log('API Base URL:', config.baseUrl);
  console.log('Running in Capacitor:', config.isCapacitor);
  console.log('Saved API URL:', localStorage.getItem('api_base_url'));
  console.groupEnd();
}
