"""
Jurisdiction-Finder Agent
Finds jurisdictions for given coordinates using PostGIS spatial queries
"""

import psycopg2
from psycopg2.extras import RealDictCursor
import logging
from typing import List, Dict, Optional
import os

logger = logging.getLogger(__name__)

class JurisdictionFinderAgent:
    """Agent for finding jurisdictions based on geographic coordinates"""
    
    def __init__(self, db_config: Optional[Dict] = None):
        self.db_config = db_config or {
            'host': os.getenv('DB_HOST', 'localhost'),
            'port': os.getenv('DB_PORT', '5432'),
            'user': os.getenv('DB_USER', 'postgres'),
            'password': os.getenv('DB_PASSWORD', ''),
            'database': os.getenv('DB_NAME', 'codecheck')
        }
    
    def get_connection(self):
        """Get database connection"""
        return psycopg2.connect(**self.db_config)
    
    def find_jurisdictions(self, latitude: float, longitude: float) -> List[Dict]:
        """
        Find all jurisdictions containing the given coordinates
        
        Args:
            latitude: Latitude coordinate
            longitude: Longitude coordinate
            
        Returns:
            List of jurisdiction dictionaries ordered by specificity
        """
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT id, name, type, fips_code, municode_url, 
                           ecode360_url, official_portal_url
                    FROM jurisdiction
                    WHERE ST_Contains(geo_boundary, ST_SetSRID(ST_MakePoint(%s, %s), 4326))
                    ORDER BY 
                        CASE type 
                            WHEN 'city' THEN 1
                            WHEN 'town' THEN 2
                            WHEN 'county' THEN 3
                            WHEN 'state' THEN 4
                            ELSE 5
                        END
                """, (longitude, latitude))
                
                jurisdictions = []
                for row in cursor.fetchall():
                    jurisdictions.append(dict(row))
                
                logger.info(f"Found {len(jurisdictions)} jurisdictions for coordinates ({latitude}, {longitude})")
                return jurisdictions
                
        except Exception as e:
            logger.error(f"Error finding jurisdictions: {e}")
            raise
        finally:
            conn.close()
    
    def find_primary_jurisdiction(self, latitude: float, longitude: float) -> Optional[Dict]:
        """
        Find the most specific jurisdiction (city > town > county > state)
        
        Args:
            latitude: Latitude coordinate
            longitude: Longitude coordinate
            
        Returns:
            Most specific jurisdiction or None if not found
        """
        jurisdictions = self.find_jurisdictions(latitude, longitude)
        return jurisdictions[0] if jurisdictions else None
    
    def validate_coordinates(self, latitude: float, longitude: float) -> bool:
        """
        Validate that coordinates are within reasonable bounds
        
        Args:
            latitude: Latitude coordinate
            longitude: Longitude coordinate
            
        Returns:
            True if coordinates are valid, False otherwise
        """
        return (-90 <= latitude <= 90 and -180 <= longitude <= 180)
    
    def get_jurisdiction_by_id(self, jurisdiction_id: str) -> Optional[Dict]:
        """
        Get jurisdiction details by ID
        
        Args:
            jurisdiction_id: UUID of the jurisdiction
            
        Returns:
            Jurisdiction dictionary or None if not found
        """
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT id, name, type, fips_code, municode_url, 
                           ecode360_url, official_portal_url
                    FROM jurisdiction
                    WHERE id = %s
                """, (jurisdiction_id,))
                
                row = cursor.fetchone()
                return dict(row) if row else None
                
        except Exception as e:
            logger.error(f"Error getting jurisdiction by ID: {e}")
            raise
        finally:
            conn.close()