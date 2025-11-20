"""
Source Discovery Agent
Discovers building code sources for a given jurisdiction

MVP Implementation:
- Returns hardcoded model codes (IRC 2021, IBC 2021) for MVP
- Can be enhanced later with real web scraping capabilities
- Provides foundation for discovering jurisdiction-specific codes
"""

import logging
from typing import List, Dict, Optional
from dataclasses import dataclass
from datetime import datetime

logger = logging.getLogger(__name__)

@dataclass
class CodeSource:
    """Represents a building code source"""
    name: str
    url: str
    type: str  # 'model_code', 'state_code', 'municipal_code', 'amendment'
    code_family: str  # 'IRC', 'IBC', 'IECC', 'IFC', 'NEC', etc.
    edition: str  # '2018', '2021', '2024', etc.
    description: Optional[str] = None
    priority: int = 1  # Higher priority sources override lower ones


class SourceDiscoveryAgent:
    """
    Agent responsible for discovering building code sources for jurisdictions

    MVP Approach:
    - Returns model codes (IRC 2021, IBC 2021) as fallback
    - Foundation for future enhancements with web scraping

    Future Enhancements:
    - Web scraping ICC website for adopted codes
    - State building department website scraping
    - Municipal code website integration (Municode, eCode360)
    - API integration with ICC Digital Codes
    - Amendment discovery from local ordinances
    """

    def __init__(self):
        self.model_codes = self._initialize_model_codes()

    def _initialize_model_codes(self) -> List[CodeSource]:
        """Initialize default model code sources"""
        return [
            CodeSource(
                name="ICC International Residential Code (IRC) 2021",
                url="https://codes.iccsafe.org/content/IRC2021P1",
                type="model_code",
                code_family="IRC",
                edition="2021",
                description="Residential building code for one- and two-family dwellings",
                priority=1
            ),
            CodeSource(
                name="ICC International Building Code (IBC) 2021",
                url="https://codes.iccsafe.org/content/IBC2021P1",
                type="model_code",
                code_family="IBC",
                edition="2021",
                description="Commercial and multi-family building code",
                priority=1
            ),
            CodeSource(
                name="ICC International Fire Code (IFC) 2021",
                url="https://codes.iccsafe.org/content/IFC2021P1",
                type="model_code",
                code_family="IFC",
                edition="2021",
                description="Fire prevention and life safety code",
                priority=2
            ),
            CodeSource(
                name="National Electrical Code (NEC) 2020",
                url="https://www.nfpa.org/codes-and-standards/all-codes-and-standards/list-of-codes-and-standards/detail?code=70",
                type="model_code",
                code_family="NEC",
                edition="2020",
                description="Electrical safety requirements",
                priority=2
            ),
        ]

    async def discover_sources(
        self,
        jurisdiction_name: str,
        jurisdiction_type: Optional[str] = None,
        state: Optional[str] = None
    ) -> List[Dict[str, str]]:
        """
        Discover building code sources for a jurisdiction

        Args:
            jurisdiction_name: Name of jurisdiction (e.g., "Denver", "Austin, TX")
            jurisdiction_type: Type of jurisdiction ('city', 'county', 'state')
            state: State abbreviation for filtering state-specific codes

        Returns:
            List of source dictionaries with name, url, type, code_family, edition

        MVP: Returns model codes for all jurisdictions
        Future: Will implement jurisdiction-specific discovery
        """
        logger.info(f"Discovering code sources for {jurisdiction_name}")

        try:
            # MVP: Return model codes for all jurisdictions
            # This ensures we always have codes to extract from
            sources = self._get_model_code_sources()

            # Future enhancement: Add jurisdiction-specific source discovery
            # jurisdiction_sources = await self._discover_jurisdiction_sources(
            #     jurisdiction_name, jurisdiction_type, state
            # )
            # if jurisdiction_sources:
            #     sources.extend(jurisdiction_sources)

            logger.info(f"Discovered {len(sources)} code sources for {jurisdiction_name}")
            return sources

        except Exception as e:
            logger.error(f"Error discovering sources for {jurisdiction_name}: {e}")
            # Fallback to model codes on error
            return self._get_model_code_sources()

    def _get_model_code_sources(self) -> List[Dict[str, str]]:
        """
        Get model code sources as dictionaries

        Returns primary codes (IRC, IBC) for MVP
        Can be expanded to include IFC, NEC, etc.
        """
        # For MVP, return just IRC and IBC (most commonly used)
        primary_codes = [source for source in self.model_codes
                        if source.code_family in ['IRC', 'IBC']]

        return [
            {
                'name': source.name,
                'url': source.url,
                'type': source.type,
                'code_family': source.code_family,
                'edition': source.edition,
                'description': source.description or '',
                'priority': source.priority
            }
            for source in primary_codes
        ]

    async def _discover_jurisdiction_sources(
        self,
        jurisdiction_name: str,
        jurisdiction_type: Optional[str],
        state: Optional[str]
    ) -> List[Dict[str, str]]:
        """
        Discover jurisdiction-specific code sources (future enhancement)

        This method is a placeholder for future implementation that will:
        1. Check state building department websites
        2. Search Municode/eCode360 for local ordinances
        3. Query ICC database for adopted codes
        4. Discover local amendments

        Args:
            jurisdiction_name: Name of jurisdiction
            jurisdiction_type: Type of jurisdiction
            state: State abbreviation

        Returns:
            List of jurisdiction-specific sources
        """
        # TODO: Implement jurisdiction-specific source discovery
        # Steps:
        # 1. Check state building code authority website
        # 2. Search Municode.com for jurisdiction
        # 3. Search eCode360.com for jurisdiction
        # 4. Query ICC Digital Codes API
        # 5. Search for local amendments in official portals

        logger.debug(f"Jurisdiction-specific discovery not yet implemented for {jurisdiction_name}")
        return []

    def get_source_priority(self, source: Dict[str, str]) -> int:
        """
        Determine priority of a source for conflict resolution

        Priority order:
        1. Local amendments (highest priority)
        2. Municipal codes
        3. State codes
        4. Model codes (lowest priority)

        Args:
            source: Source dictionary

        Returns:
            Priority score (higher = more authoritative)
        """
        priority_map = {
            'amendment': 4,
            'municipal_code': 3,
            'state_code': 2,
            'model_code': 1
        }
        return priority_map.get(source.get('type', 'model_code'), 1)

    def validate_source(self, source: Dict[str, str]) -> bool:
        """
        Validate that a source has all required fields

        Args:
            source: Source dictionary

        Returns:
            True if valid, False otherwise
        """
        required_fields = ['name', 'url', 'type', 'code_family', 'edition']
        return all(field in source and source[field] for field in required_fields)

    def get_supported_code_families(self) -> List[str]:
        """Get list of supported code families"""
        return ['IRC', 'IBC', 'IFC', 'NEC', 'IECC', 'IPC', 'IMC', 'IFGC']

    def get_available_editions(self, code_family: str) -> List[str]:
        """
        Get available editions for a code family

        Args:
            code_family: Code family (IRC, IBC, etc.)

        Returns:
            List of available editions
        """
        # ICC codes follow 3-year cycle
        if code_family in ['IRC', 'IBC', 'IFC', 'IECC', 'IPC', 'IMC', 'IFGC']:
            return ['2024', '2021', '2018', '2015', '2012']
        # NEC follows 3-year cycle with different years
        elif code_family == 'NEC':
            return ['2023', '2020', '2017', '2014', '2011']
        return []


# Convenience function for easy instantiation
def create_source_discovery_agent() -> SourceDiscoveryAgent:
    """Create and return a SourceDiscoveryAgent instance"""
    return SourceDiscoveryAgent()


# Example usage for testing
if __name__ == "__main__":
    import asyncio

    async def test_source_discovery():
        agent = create_source_discovery_agent()

        # Test discovery for different jurisdictions
        test_jurisdictions = [
            ("Denver, CO", "city", "CO"),
            ("Austin, TX", "city", "TX"),
            ("Seattle, WA", "city", "WA"),
        ]

        for name, jtype, state in test_jurisdictions:
            print(f"\n{'='*60}")
            print(f"Testing source discovery for: {name}")
            print(f"{'='*60}")

            sources = await agent.discover_sources(name, jtype, state)

            print(f"Found {len(sources)} sources:")
            for source in sources:
                print(f"\n- {source['name']}")
                print(f"  Family: {source['code_family']} {source['edition']}")
                print(f"  Type: {source['type']}")
                print(f"  URL: {source['url']}")
                print(f"  Priority: {agent.get_source_priority(source)}")

    # Run test
    asyncio.run(test_source_discovery())
