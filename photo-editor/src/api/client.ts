/**
 * CodeCheck API Client
 *
 * Handles API communication with environment-aware URL configuration.
 * Automatically detects if running in browser or Capacitor (iOS/Android)
 * and uses the appropriate API base URL.
 */

export interface Violation {
  element: string;
  issue: string;
  code_reference: string;
  severity: 'high' | 'medium' | 'low';
  confidence: number;
  explanation: string;
}

export interface AnalysisResult {
  summary: string;
  elements_detected: string[];
  potential_violations: Violation[];
  observations: string[];
  overall_status: 'pass' | 'fail' | 'warning';
}

export interface NetworkInfo {
  local_ip: string;
  api_base_url: string;
  localhost_url: string;
  port: number;
  environment: string;
}

/**
 * Check if we're running in Capacitor (native app)
 */
function isCapacitor(): boolean {
  return !!(window as any).Capacitor;
}

/**
 * Get the API base URL based on the current environment
 */
function getApiBaseUrl(): string {
  // Check if there's an environment variable set (for production)
  const envApiUrl = import.meta.env.VITE_API_BASE_URL;
  if (envApiUrl) {
    return envApiUrl;
  }

  // If running in Capacitor (native app), use network IP
  if (isCapacitor()) {
    // Default to localhost:8000 for simulator
    // In production, this should be fetched from the backend
    const savedUrl = localStorage.getItem('api_base_url');
    return savedUrl || 'http://localhost:8000';
  }

  // Browser: use proxy (relative URLs work through Vite proxy)
  return '';
}

const API_BASE_URL = getApiBaseUrl();

/**
 * Make an API request with proper error handling
 */
async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  const url = `${API_BASE_URL}${endpoint}`;

  try {
    const response = await fetch(url, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(
        errorData.detail || `Request failed: ${response.status} ${response.statusText}`
      );
    }

    return response.json();
  } catch (error) {
    if (error instanceof Error) {
      throw error;
    }
    throw new Error('Network request failed');
  }
}

/**
 * Fetch network info from the backend
 * Used to configure the API URL for Capacitor apps
 */
export async function fetchNetworkInfo(baseUrl?: string): Promise<NetworkInfo> {
  const url = baseUrl
    ? `${baseUrl}/api/connectivity/network-info`
    : `${API_BASE_URL}/api/connectivity/network-info`;

  const response = await fetch(url);

  if (!response.ok) {
    throw new Error('Failed to fetch network info');
  }

  return response.json();
}

/**
 * Auto-configure API URL for Capacitor apps
 * Call this on app startup to detect the correct backend URL
 */
export async function configureApiUrl(): Promise<string> {
  if (!isCapacitor()) {
    // Browser: no configuration needed
    return API_BASE_URL;
  }

  try {
    // Try localhost first (for simulator)
    const info = await fetchNetworkInfo('http://localhost:8000');

    // If we got network info, save it
    if (info.local_ip && !info.is_localhost) {
      // Use the network IP for real devices
      const apiUrl = info.api_base_url;
      localStorage.setItem('api_base_url', apiUrl);
      return apiUrl;
    }

    // Use localhost for simulator
    localStorage.setItem('api_base_url', info.localhost_url);
    return info.localhost_url;
  } catch (error) {
    console.error('Failed to configure API URL:', error);

    // Fallback to localhost
    const fallback = 'http://localhost:8000';
    localStorage.setItem('api_base_url', fallback);
    return fallback;
  }
}

/**
 * Test if the backend is reachable
 */
export async function testConnection(): Promise<boolean> {
  try {
    const response = await fetch(`${API_BASE_URL}/api/connectivity/health`, {
      method: 'GET',
      signal: AbortSignal.timeout(5000), // 5 second timeout
    });

    return response.ok;
  } catch (error) {
    console.error('Connection test failed:', error);
    return false;
  }
}

/**
 * Get connectivity status from the backend
 */
export async function getConnectivityStatus(): Promise<any> {
  return apiRequest('/api/connectivity/status');
}

/**
 * Analyze an image for code compliance
 */
export async function analyzeImage(base64Image: string): Promise<AnalysisResult> {
  // Remove data:image/jpeg;base64, prefix if present
  const cleanBase64 = base64Image.replace(/^data:image\/\w+;base64,/, '');

  return apiRequest<AnalysisResult>('/api/analyze/image', {
    method: 'POST',
    body: JSON.stringify({
      image_base64: cleanBase64,
      media_type: 'image/jpeg',
      context: {
        jurisdiction: 'Default Jurisdiction',
        project_type: 'Residential',
      },
    }),
  });
}

/**
 * Get the current API configuration
 */
export function getApiConfig() {
  return {
    baseUrl: API_BASE_URL,
    isCapacitor: isCapacitor(),
    environment: import.meta.env.MODE,
  };
}
