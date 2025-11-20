"""
Document Fetcher Agent
Fetches building code documents from various sources

MVP Implementation:
- Returns sample code text for MVP testing
- Can be enhanced later with real PDF/HTML fetching
- Provides foundation for document extraction
"""

import logging
from typing import Dict, Optional
from dataclasses import dataclass
import asyncio

logger = logging.getLogger(__name__)

@dataclass
class Document:
    """Represents a fetched building code document"""
    source_name: str
    code_family: str
    edition: str
    content: str
    content_type: str  # 'text', 'pdf', 'html'
    url: Optional[str] = None
    metadata: Optional[Dict] = None


class DocumentFetcherAgent:
    """
    Agent responsible for fetching building code documents

    MVP Approach:
    - Returns sample code text for common building elements
    - Enables immediate testing without external dependencies

    Future Enhancements:
    - PDF download and text extraction
    - HTML scraping from Municode/eCode360
    - ICC Digital Codes API integration
    - OCR for scanned documents
    - Caching layer for performance
    """

    def __init__(self):
        self.sample_documents = self._initialize_sample_documents()

    def _initialize_sample_documents(self) -> Dict[str, str]:
        """
        Initialize sample building code text for MVP

        These are representative samples of actual IRC/IBC code sections
        that cover common residential construction elements
        """
        return {
            'IRC_2021': """
CHAPTER 3 BUILDING PLANNING

SECTION R311 MEANS OF EGRESS

R311.3.1 Floor elevations for other exterior doors.
Doors other than the required egress door shall be provided with landings or floors
not more than 7 3/4 inches (196 mm) below the top of the threshold.

R311.3.2 Floor elevations at the required egress door.
Landings or floors at the required egress door shall be not more than 1 1/2 inches
(38 mm) lower than the top of the threshold.

SECTION R311.7 STAIRWAYS

R311.7.1 Width.
Stairways shall be not less than 36 inches (914 mm) in clear width at all points
above the permitted handrail height and below the required headroom height.

R311.7.2 Headroom.
The headroom in stairways shall be not less than 6 feet 8 inches (2032 mm) measured
vertically from the sloped plane adjoining the tread nosing or from the floor surface
of the landing or platform on that portion of the stairway.

R311.7.3 Riser height and tread depth.
Stairway riser heights shall be 7 3/4 inches (196 mm) maximum and 4 inches (102 mm)
minimum. The riser height shall be measured vertically between leading edges of the
adjacent treads. The greatest riser height within any flight of stairs shall not exceed
the smallest by more than 3/8 inch (9.5 mm).

Stairway tread depths shall be 11 inches (279 mm) minimum. The tread depth shall be
measured horizontally between the vertical planes of the foremost projection of adjacent
treads and at a right angle to the tread's leading edge. The greatest tread depth within
any flight of stairs shall not exceed the smallest by more than 3/8 inch (9.5 mm).

Winder treads shall have a minimum tread depth of 11 inches (279 mm) measured at a
right angle to the tread's leading edge at a point 12 inches (305 mm) from the side
where the treads are narrower.

R311.7.4 Walkline.
The walkline across winder treads shall be concentric to the direction of travel through
the turn and located 12 inches (305 mm) from the side where the winders are narrower.
The 12-inch (305 mm) dimension shall be measured from the widest point of the clear
stairway width at the walkline. Where winders are adjacent within a flight, the
point of minimum tread depth of adjacent winders shall be located at the same distance
from the narrow side of the stairway.

R311.7.5 Landings for stairways.
There shall be a floor or landing at the top and bottom of each stairway. The width
perpendicular to the direction of travel shall be not less than the width of the flight
served. Where a stairway has a straight run, the depth in the direction of travel shall
be not less than 36 inches (914 mm).

R311.7.6 Handrails.
Handrails shall be provided on not less than one side of each continuous run of treads
or flight with four or more risers.

SECTION R312 GUARDS

R312.1 Guards.
Porches, balconies, ramps, or raised floor surfaces located more than 30 inches (762 mm)
above the floor or grade below shall have guards not less than 36 inches (914 mm) in
height. Open sides of stairs with a total rise of more than 30 inches (762 mm) above
the floor or grade below shall have guards not less than 34 inches (864 mm) in height
measured vertically from the nosing of the treads.

R312.2 Guard opening limitations.
Required guards shall have intermediate rails or ornamental closures which do not allow
passage of a sphere 4 inches (102 mm) in diameter.

Exceptions:
1. The triangular openings at the open sides of stairs formed by the riser, tread,
   and bottom rail of a guard shall not allow passage of a sphere 6 inches (152 mm)
   in diameter.
2. Guards on the open sides of stairs shall not have openings which allow passage of
   a sphere 4 3/8 inches (107 mm) in diameter.
3. Pickets or balusters on guards shall not be spaced to permit passage of a sphere
   4 inches (102 mm) in diameter.

CHAPTER 4 FOUNDATIONS

SECTION R403 FOOTINGS

R403.1 General.
All exterior walls shall be supported on continuous solid or masonry foundations.

CHAPTER 6 WALL CONSTRUCTION

SECTION R602 WOOD WALL FRAMING

R602.3 Design and construction.
Exterior walls of wood-frame construction shall be designed and constructed in accordance
with the provisions of this chapter and Figures R602.3(1) and R602.3(2) or in accordance
with AF&PA's NDS.

CHAPTER 11 ENERGY EFFICIENCY

SECTION R1101 GENERAL

R1101.1 Scope.
The provisions contained in this chapter are applicable to the design of buildings for
energy efficiency. This chapter is not applicable to historic buildings.
""",

            'IBC_2021': """
CHAPTER 10 MEANS OF EGRESS

SECTION 1005 EGRESS WIDTH

1005.1 Minimum required egress width.
The means of egress width shall not be less than required by this section. The total
width of means of egress in inches shall not be less than the total occupant load served
by the means of egress multiplied by 0.3 inch per occupant for stairways and by 0.2 inch
per occupant for other egress components.

SECTION 1009 STAIRWAYS AND HANDRAILS

1009.1 Stairway width.
The width of stairways shall be determined as specified in Section 1005.1, but such
width shall not be less than 44 inches.

Exception: Stairways serving an occupant load of less than 50 shall have a width of
not less than 36 inches.

1009.2 Headroom.
Stairways shall have a headroom clearance of not less than 80 inches measured vertically
from a line connecting the edge of the nosings. Such headroom shall be continuous above
the stairway to the point where the line intersects the landing below, one tread depth
beyond the bottom riser.

1009.3 Stair treads and risers.
Stair riser heights shall be 7 inches maximum and 4 inches minimum. The riser height
shall be measured vertically between the leading edges of adjacent treads. The greatest
riser height within any flight of stairs shall not exceed the smallest by more than 3/8 inch.

Stair tread depths shall be 11 inches minimum. The tread depth shall be measured
horizontally between the vertical planes of the foremost projection of adjacent treads
and at a right angle to the tread's leading edge.

1009.4 Stairway landings.
There shall be a floor or landing at the top and bottom of each stairway. The width of
landings shall be not less than the width of stairways they serve. Every landing shall
have a minimum depth, measured in the direction of travel, equal to the width of the
stairway. Such depth need not exceed 48 inches where the stairway has a straight run.

1009.5 Stairway construction.
All stairways shall be built of materials consistent with the types permitted for the
type of construction of the building, except that wood handrails shall be permitted for
all types of construction.

SECTION 1013 GUARDS

1013.1 Where required.
Guards shall be located along open-sided walking surfaces, including mezzanines,
equipment platforms, aisles, stairs, ramps and landings that are located more than
30 inches measured vertically to the floor or grade below at any point within 36 inches
horizontally to the edge of the open side.

1013.2 Height.
Required guards shall be not less than 42 inches high, measured vertically as follows:
1. From the adjacent walking surface.
2. On stairways and stepped aisles, from the line connecting the leading edges of the
   tread nosings.
3. On ramps and ramped aisles, from the ramp surface at the guard.

1013.3 Opening limitations.
Required guards shall not have openings from the walking surface to the required guard
height which allow passage of a sphere 4 inches in diameter.

Exceptions:
1. The triangular openings at the open sides of stair formed by the riser, tread and
   bottom rail of a guard shall not allow passage of a sphere 6 inches in diameter.
2. At elevated walking surfaces for access to and use of electrical, mechanical or
   plumbing systems or equipment, guards shall not have openings which allow passage
   of a sphere 21 inches in diameter.

CHAPTER 16 STRUCTURAL DESIGN

SECTION 1607 LIVE LOADS

1607.1 General.
Live loads are those loads defined in Section 202. Minimum uniformly distributed and
concentrated live loads shall be as set forth in Table 1607.1.

CHAPTER 29 PLUMBING SYSTEMS

SECTION 2902 MINIMUM NUMBER OF FIXTURES

2902.1 Minimum number of fixtures.
Plumbing fixtures shall be provided in the minimum number as shown in Table 2902.1
based upon the actual use of the building or space.
"""
        }

    async def fetch_document(self, source: Dict[str, str]) -> Optional[Document]:
        """
        Fetch document from source

        Args:
            source: Source dictionary with name, url, type, code_family, edition

        Returns:
            Document object with content, or None if fetch fails

        MVP: Returns sample text from hardcoded documents
        Future: Will fetch from actual URLs, PDFs, APIs
        """
        try:
            code_family = source.get('code_family', '')
            edition = source.get('edition', '')
            source_name = source.get('name', '')
            url = source.get('url', '')

            logger.info(f"Fetching document: {source_name}")

            # MVP: Return sample document text
            content = self._get_sample_document(code_family, edition)

            if not content:
                logger.warning(f"No sample document available for {code_family} {edition}")
                return None

            # Simulate network delay for realism
            await asyncio.sleep(0.5)

            document = Document(
                source_name=source_name,
                code_family=code_family,
                edition=edition,
                content=content,
                content_type='text',
                url=url,
                metadata={
                    'source_type': source.get('type', 'unknown'),
                    'priority': source.get('priority', 1),
                    'fetched_at': asyncio.get_event_loop().time()
                }
            )

            logger.info(f"Successfully fetched document: {source_name} ({len(content)} characters)")
            return document

        except Exception as e:
            logger.error(f"Error fetching document from {source.get('name', 'unknown')}: {e}")
            return None

    def _get_sample_document(self, code_family: str, edition: str) -> Optional[str]:
        """
        Get sample document text for a code family and edition

        Args:
            code_family: Code family (IRC, IBC, etc.)
            edition: Edition year

        Returns:
            Sample document text, or None if not available
        """
        # For MVP, we have sample text for IRC 2021 and IBC 2021
        key = f"{code_family}_{edition}"

        if key in self.sample_documents:
            return self.sample_documents[key]

        # Fallback to similar edition if exact match not found
        if code_family == 'IRC':
            return self.sample_documents.get('IRC_2021')
        elif code_family == 'IBC':
            return self.sample_documents.get('IBC_2021')

        return None

    async def fetch_document_from_url(self, url: str, document_type: str = 'auto') -> Optional[str]:
        """
        Fetch document from URL (future enhancement)

        This method is a placeholder for future implementation that will:
        1. Download PDF files
        2. Extract text from PDFs
        3. Scrape HTML content
        4. Handle authentication if needed

        Args:
            url: URL to fetch document from
            document_type: Type of document ('pdf', 'html', 'auto')

        Returns:
            Extracted document text, or None if fetch fails
        """
        # TODO: Implement actual URL fetching
        # Steps:
        # 1. Download document from URL
        # 2. Detect document type if 'auto'
        # 3. Extract text based on document type:
        #    - PDF: Use PyPDF2, pdfplumber, or PDFMiner
        #    - HTML: Use BeautifulSoup or lxml
        # 4. Clean and normalize text
        # 5. Return extracted content

        logger.debug(f"URL fetching not yet implemented for: {url}")
        return None

    async def fetch_pdf_document(self, pdf_path: str) -> Optional[str]:
        """
        Extract text from PDF document (future enhancement)

        Args:
            pdf_path: Path to PDF file

        Returns:
            Extracted text, or None if extraction fails
        """
        # TODO: Implement PDF text extraction
        # Libraries to consider:
        # - PyPDF2: Simple, fast, works for most PDFs
        # - pdfplumber: Better for tables and complex layouts
        # - PDFMiner: More control, handles complex PDFs
        # - Tesseract OCR: For scanned documents

        logger.debug(f"PDF extraction not yet implemented for: {pdf_path}")
        return None

    def validate_document(self, document: Document) -> bool:
        """
        Validate that document has usable content

        Args:
            document: Document object to validate

        Returns:
            True if document is valid, False otherwise
        """
        if not document:
            return False

        # Check required fields
        if not document.content or len(document.content) < 100:
            logger.warning(f"Document {document.source_name} has insufficient content")
            return False

        if not document.code_family or not document.edition:
            logger.warning(f"Document {document.source_name} missing metadata")
            return False

        # Check for common error indicators
        error_indicators = [
            '404 not found',
            'access denied',
            'page not found',
            'error occurred'
        ]
        content_lower = document.content.lower()
        if any(indicator in content_lower for indicator in error_indicators):
            logger.warning(f"Document {document.source_name} contains error indicators")
            return False

        return True

    def get_document_stats(self, document: Document) -> Dict[str, any]:
        """
        Get statistics about a document

        Args:
            document: Document to analyze

        Returns:
            Dictionary with stats (character count, section count, etc.)
        """
        if not document:
            return {}

        content = document.content
        sections = content.count('SECTION')
        chapters = content.count('CHAPTER')

        return {
            'character_count': len(content),
            'word_count': len(content.split()),
            'line_count': len(content.split('\n')),
            'section_count': sections,
            'chapter_count': chapters,
            'code_family': document.code_family,
            'edition': document.edition
        }


# Convenience function for easy instantiation
def create_document_fetcher_agent() -> DocumentFetcherAgent:
    """Create and return a DocumentFetcherAgent instance"""
    return DocumentFetcherAgent()


# Example usage for testing
if __name__ == "__main__":
    async def test_document_fetcher():
        agent = create_document_fetcher_agent()

        # Test sources
        test_sources = [
            {
                'name': 'ICC IRC 2021',
                'url': 'https://codes.iccsafe.org/content/IRC2021P1',
                'type': 'model_code',
                'code_family': 'IRC',
                'edition': '2021',
                'priority': 1
            },
            {
                'name': 'ICC IBC 2021',
                'url': 'https://codes.iccsafe.org/content/IBC2021P1',
                'type': 'model_code',
                'code_family': 'IBC',
                'edition': '2021',
                'priority': 1
            }
        ]

        for source in test_sources:
            print(f"\n{'='*60}")
            print(f"Testing document fetch for: {source['name']}")
            print(f"{'='*60}")

            document = await agent.fetch_document(source)

            if document and agent.validate_document(document):
                stats = agent.get_document_stats(document)
                print(f"\nSuccessfully fetched document:")
                print(f"- Source: {document.source_name}")
                print(f"- Code Family: {document.code_family} {document.edition}")
                print(f"- Content Type: {document.content_type}")
                print(f"- Character Count: {stats['character_count']:,}")
                print(f"- Word Count: {stats['word_count']:,}")
                print(f"- Section Count: {stats['section_count']}")
                print(f"- Chapter Count: {stats['chapter_count']}")
                print(f"\nFirst 200 characters:")
                print(document.content[:200] + "...")
            else:
                print(f"Failed to fetch or validate document")

    # Run test
    asyncio.run(test_document_fetcher())
