"""
Network Utilities

Helper functions for network configuration and IP detection.
Used for iOS connectivity to auto-detect the correct API URL.
"""

import socket
import os
from typing import Optional, List


def get_local_ip() -> Optional[str]:
    """
    Get the local network IP address of this machine.

    Returns the IP address that can be used by devices on the same network
    to connect to this backend.

    Returns:
        IP address string (e.g., '192.168.1.100') or None if unable to detect
    """
    try:
        # Create a socket and connect to an external address
        # This doesn't actually send data, just determines the interface
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception:
        # Fallback: try to get hostname IP
        try:
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return None


def get_all_network_interfaces() -> List[dict]:
    """
    Get information about all network interfaces.

    Returns:
        List of dictionaries with interface information
    """
    import netifaces

    interfaces = []

    try:
        for interface in netifaces.interfaces():
            addrs = netifaces.ifaddresses(interface)

            # Get IPv4 addresses
            if netifaces.AF_INET in addrs:
                for addr in addrs[netifaces.AF_INET]:
                    interfaces.append({
                        'interface': interface,
                        'ip': addr['addr'],
                        'netmask': addr.get('netmask'),
                        'type': 'IPv4'
                    })
    except ImportError:
        # netifaces not installed - use simple method
        pass

    return interfaces


def get_api_base_url(include_protocol: bool = True, port: Optional[int] = None) -> str:
    """
    Get the API base URL that external clients should use.

    Args:
        include_protocol: Whether to include http:// prefix
        port: Port number (defaults to API_PORT env var or 8000)

    Returns:
        Full API base URL (e.g., 'http://192.168.1.100:8000')
    """
    local_ip = get_local_ip()

    if not local_ip:
        local_ip = 'localhost'

    if port is None:
        port = int(os.getenv('API_PORT', 8000))

    protocol = 'http://' if include_protocol else ''

    return f"{protocol}{local_ip}:{port}"


def is_localhost(ip: str) -> bool:
    """
    Check if an IP address is localhost.

    Args:
        ip: IP address string

    Returns:
        True if localhost, False otherwise
    """
    return ip in ['localhost', '127.0.0.1', '::1', '0.0.0.0']


def get_connection_info() -> dict:
    """
    Get comprehensive connection information for clients.

    Returns:
        Dictionary with connection details:
        - local_ip: Network IP address
        - api_base_url: Full API URL
        - localhost_url: Localhost URL
        - port: API port
        - environment: Current environment
    """
    port = int(os.getenv('API_PORT', 8000))
    local_ip = get_local_ip()
    environment = os.getenv('ENVIRONMENT', 'development')

    return {
        'local_ip': local_ip,
        'api_base_url': get_api_base_url(),
        'localhost_url': f'http://localhost:{port}',
        'port': port,
        'environment': environment,
        'is_localhost': local_ip is None or is_localhost(local_ip)
    }
