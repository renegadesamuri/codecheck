"""
Agent Coordinator for On-Demand Code Loading
Orchestrates the multi-agent workflow for jurisdiction code loading

Workflow:
1. Source Discovery (33% progress)
2. Document Fetching (66% progress)
3. Rule Extraction (100% progress)
4. Database Persistence

Features:
- Progress callback support for real-time updates
- Comprehensive error handling with fallbacks
- Automatic fallback to model codes
- Database integration for rule persistence
- Logging for debugging and monitoring
"""

import logging
import os
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, List, Optional, Callable, Any
from datetime import datetime
import uuid

# Import agent modules
from source_discovery_agent import SourceDiscoveryAgent, create_source_discovery_agent
from document_fetcher_agent import DocumentFetcherAgent, create_document_fetcher_agent
from enhanced_rule_extractor import EnhancedRuleExtractor, create_enhanced_extractor
from claude_integration import ClaudeConfig

logger = logging.getLogger(__name__)

# Type alias for progress callback
ProgressCallback = Callable[[int, str], None]


class AgentCoordinator:
    """
    Coordinates multi-agent workflow for jurisdiction code loading

    Orchestrates source discovery, document fetching, and rule extraction
    with progress tracking and comprehensive error handling.
    """

    def __init__(
        self,
        db_config: Optional[Dict[str, str]] = None,
        claude_api_key: Optional[str] = None
    ):
        """
        Initialize AgentCoordinator

        Args:
            db_config: Database connection configuration
            claude_api_key: Claude API key for rule extraction
        """
        # Initialize agents
        self.source_agent = create_source_discovery_agent()
        self.fetcher_agent = create_document_fetcher_agent()

        # Initialize rule extractor with Claude
        api_key = claude_api_key or os.getenv('CLAUDE_API_KEY')
        if not api_key:
            logger.warning("Claude API key not provided, rule extraction may fail")
            self.extractor_agent = None
        else:
            try:
                self.extractor_agent = create_enhanced_extractor(api_key)
            except Exception as e:
                logger.error(f"Failed to initialize rule extractor: {e}")
                self.extractor_agent = None

        # Database configuration
        self.db_config = db_config or self._get_default_db_config()

        logger.info("AgentCoordinator initialized successfully")

    def _get_default_db_config(self) -> Dict[str, str]:
        """Get default database configuration from environment"""
        return {
            'host': os.getenv('DB_HOST', 'localhost'),
            'port': os.getenv('DB_PORT', '5432'),
            'user': os.getenv('DB_USER', 'postgres'),
            'password': os.getenv('DB_PASSWORD', ''),
            'database': os.getenv('DB_NAME', 'codecheck')
        }

    def _get_db_connection(self):
        """Get database connection"""
        try:
            conn = psycopg2.connect(
                host=self.db_config['host'],
                port=self.db_config['port'],
                user=self.db_config['user'],
                password=self.db_config['password'],
                database=self.db_config['database']
            )
            return conn
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            raise

    async def load_codes_for_jurisdiction(
        self,
        jurisdiction_id: str,
        jurisdiction_name: str,
        jurisdiction_type: Optional[str] = None,
        state: Optional[str] = None,
        progress_callback: Optional[ProgressCallback] = None
    ) -> Dict[str, Any]:
        """
        Full workflow to load codes for a jurisdiction

        Args:
            jurisdiction_id: UUID of jurisdiction
            jurisdiction_name: Name of jurisdiction (e.g., "Denver, CO")
            jurisdiction_type: Type of jurisdiction ('city', 'county', 'state')
            state: State abbreviation (e.g., "CO")
            progress_callback: Optional callback function(progress: int, message: str)

        Returns:
            Dictionary with results:
            {
                "success": bool,
                "rules_count": int,
                "sources_found": int,
                "sources_used": int,
                "error": str (optional)
            }
        """
        logger.info(f"Starting code loading for jurisdiction: {jurisdiction_name} ({jurisdiction_id})")

        try:
            # ========== STEP 1: Discover Sources (0-33%) ==========
            if progress_callback:
                progress_callback(5, "Initializing code discovery...")

            logger.info(f"Step 1: Discovering code sources for {jurisdiction_name}")

            sources = await self.source_agent.discover_sources(
                jurisdiction_name=jurisdiction_name,
                jurisdiction_type=jurisdiction_type,
                state=state
            )

            if not sources:
                logger.warning(f"No sources discovered for {jurisdiction_name}, using model codes")
                sources = self._get_model_code_fallback()

            logger.info(f"Discovered {len(sources)} code sources")

            if progress_callback:
                progress_callback(33, f"Found {len(sources)} code sources")

            # ========== STEP 2: Fetch Documents (33-66%) ==========
            if progress_callback:
                progress_callback(35, "Downloading building code documents...")

            logger.info(f"Step 2: Fetching {len(sources)} documents")

            documents = []
            for i, source in enumerate(sources):
                try:
                    doc = await self.fetcher_agent.fetch_document(source)
                    if doc and self.fetcher_agent.validate_document(doc):
                        documents.append(doc)
                        logger.info(f"Successfully fetched: {source['name']}")
                    else:
                        logger.warning(f"Failed to fetch or validate: {source['name']}")
                except Exception as e:
                    logger.error(f"Error fetching document {source['name']}: {e}")
                    continue

                # Update progress
                progress = 35 + int((i + 1) / len(sources) * 31)
                if progress_callback:
                    progress_callback(progress, f"Downloaded {i+1}/{len(sources)} documents")

            if not documents:
                error_msg = "Failed to fetch any documents"
                logger.error(error_msg)
                return {
                    "success": False,
                    "rules_count": 0,
                    "sources_found": len(sources),
                    "sources_used": 0,
                    "error": error_msg
                }

            logger.info(f"Successfully fetched {len(documents)} documents")

            if progress_callback:
                progress_callback(66, f"Successfully downloaded {len(documents)} documents")

            # ========== STEP 3: Extract Rules (66-95%) ==========
            if progress_callback:
                progress_callback(68, "Extracting rules with AI...")

            logger.info(f"Step 3: Extracting rules from {len(documents)} documents")

            if not self.extractor_agent:
                error_msg = "Rule extractor not initialized (missing Claude API key)"
                logger.error(error_msg)
                return {
                    "success": False,
                    "rules_count": 0,
                    "sources_found": len(sources),
                    "sources_used": len(documents),
                    "error": error_msg
                }

            all_rules = []
            for i, doc in enumerate(documents):
                try:
                    # Extract rules from document
                    rules = await self._extract_rules_from_document(doc, jurisdiction_id)
                    all_rules.extend(rules)

                    logger.info(f"Extracted {len(rules)} rules from {doc.source_name}")
                except Exception as e:
                    logger.error(f"Error extracting rules from {doc.source_name}: {e}")
                    continue

                # Update progress
                progress = 68 + int((i + 1) / len(documents) * 27)
                if progress_callback:
                    progress_callback(progress, f"Extracted rules from {i+1}/{len(documents)} documents")

            if not all_rules:
                error_msg = "No rules could be extracted from documents"
                logger.error(error_msg)
                return {
                    "success": False,
                    "rules_count": 0,
                    "sources_found": len(sources),
                    "sources_used": len(documents),
                    "error": error_msg
                }

            logger.info(f"Successfully extracted {len(all_rules)} rules")

            if progress_callback:
                progress_callback(95, "Saving rules to database...")

            # ========== STEP 4: Save to Database (95-100%) ==========
            logger.info(f"Step 4: Saving {len(all_rules)} rules to database")

            saved_count = await self._save_rules(jurisdiction_id, all_rules)

            logger.info(f"Successfully saved {saved_count} rules to database")

            if progress_callback:
                progress_callback(100, f"Complete! Loaded {saved_count} rules")

            return {
                "success": True,
                "rules_count": saved_count,
                "sources_found": len(sources),
                "sources_used": len(documents),
                "jurisdiction_id": jurisdiction_id
            }

        except Exception as e:
            error_msg = f"Error in code loading workflow: {str(e)}"
            logger.error(error_msg, exc_info=True)

            if progress_callback:
                progress_callback(0, f"Error: {str(e)}")

            return {
                "success": False,
                "rules_count": 0,
                "sources_found": 0,
                "sources_used": 0,
                "error": error_msg
            }

    async def _extract_rules_from_document(
        self,
        document,
        jurisdiction_id: str
    ) -> List[Dict[str, Any]]:
        """
        Extract rules from a document

        Args:
            document: Document object from fetcher agent
            jurisdiction_id: UUID of jurisdiction

        Returns:
            List of extracted rule dictionaries
        """
        try:
            # Split document into sections
            sections = self._split_document_into_sections(document)

            all_rules = []
            for section in sections:
                try:
                    # Extract rules from section
                    rules = await self.extractor_agent.extract_rules(
                        section_text=section['text'],
                        section_ref=section['ref'],
                        code_family=document.code_family,
                        edition=document.edition
                    )

                    # Add jurisdiction_id to each rule
                    for rule in rules:
                        rule['jurisdiction_id'] = jurisdiction_id

                    all_rules.extend(rules)

                except Exception as e:
                    logger.error(f"Error extracting rules from section {section['ref']}: {e}")
                    continue

            return all_rules

        except Exception as e:
            logger.error(f"Error processing document {document.source_name}: {e}")
            return []

    def _split_document_into_sections(self, document) -> List[Dict[str, str]]:
        """
        Split document content into sections for extraction

        Args:
            document: Document object

        Returns:
            List of section dictionaries with 'text' and 'ref'
        """
        content = document.content
        sections = []

        # Simple section splitting by "SECTION R" or "SECTION " markers
        lines = content.split('\n')
        current_section = {'ref': 'Unknown', 'text': ''}

        for line in lines:
            # Check if line starts a new section
            if line.strip().startswith('SECTION'):
                # Save previous section if it has content
                if current_section['text'].strip():
                    sections.append(current_section)

                # Start new section
                parts = line.strip().split()
                if len(parts) >= 2:
                    current_section = {
                        'ref': parts[1],  # e.g., "R311.7"
                        'text': line + '\n'
                    }
                else:
                    current_section = {'ref': 'Unknown', 'text': line + '\n'}
            else:
                current_section['text'] += line + '\n'

        # Don't forget the last section
        if current_section['text'].strip():
            sections.append(current_section)

        logger.info(f"Split document into {len(sections)} sections")
        return sections

    async def _save_rules(self, jurisdiction_id: str, rules: List[Dict[str, Any]]) -> int:
        """
        Save extracted rules to database

        Args:
            jurisdiction_id: UUID of jurisdiction
            rules: List of rule dictionaries

        Returns:
            Number of rules successfully saved
        """
        conn = None
        saved_count = 0

        try:
            conn = self._get_db_connection()

            with conn.cursor() as cursor:
                for rule in rules:
                    try:
                        # Generate UUID for rule
                        rule_id = str(uuid.uuid4())

                        # Prepare rule_json (remove metadata fields)
                        rule_json = {
                            'category': rule.get('category', ''),
                            'requirement': rule.get('requirement', ''),
                            'unit': rule.get('unit', ''),
                            'value': rule.get('value', 0),
                            'conditions': rule.get('conditions', []),
                            'exceptions': rule.get('exceptions', []),
                            'notes': rule.get('notes', '')
                        }

                        # Insert rule
                        cursor.execute("""
                            INSERT INTO rule (
                                id, jurisdiction_id, code_family, edition,
                                section_ref, title, rule_json, confidence,
                                validation_status, created_at, updated_at
                            )
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                            ON CONFLICT (id) DO NOTHING
                        """, (
                            rule_id,
                            jurisdiction_id,
                            rule.get('code_family', 'IRC'),
                            rule.get('edition', '2021'),
                            rule.get('section_ref', ''),
                            rule.get('title', ''),
                            psycopg2.extras.Json(rule_json),
                            rule.get('confidence', 0.8),
                            'auto',
                            datetime.now(),
                            datetime.now()
                        ))

                        saved_count += 1

                    except Exception as e:
                        logger.error(f"Error saving rule: {e}")
                        continue

                # Commit all rules
                conn.commit()

                # Update jurisdiction_data_status
                cursor.execute("""
                    SELECT update_jurisdiction_status(%s, %s, %s, %s)
                """, (jurisdiction_id, 'complete', saved_count, None))
                conn.commit()

            logger.info(f"Successfully saved {saved_count} rules to database")
            return saved_count

        except Exception as e:
            logger.error(f"Error saving rules to database: {e}")
            if conn:
                conn.rollback()
            return 0

        finally:
            if conn:
                conn.close()

    def _get_model_code_fallback(self) -> List[Dict[str, str]]:
        """
        Get model code sources as fallback

        Returns:
            List of model code sources (IRC 2021, IBC 2021)
        """
        return [
            {
                'name': 'ICC International Residential Code (IRC) 2021',
                'url': 'https://codes.iccsafe.org/content/IRC2021P1',
                'type': 'model_code',
                'code_family': 'IRC',
                'edition': '2021',
                'description': 'Model residential building code',
                'priority': 1
            },
            {
                'name': 'ICC International Building Code (IBC) 2021',
                'url': 'https://codes.iccsafe.org/content/IBC2021P1',
                'type': 'model_code',
                'code_family': 'IBC',
                'edition': '2021',
                'description': 'Model commercial building code',
                'priority': 1
            }
        ]


# Convenience function for easy instantiation
def create_agent_coordinator(
    db_config: Optional[Dict[str, str]] = None,
    claude_api_key: Optional[str] = None
) -> AgentCoordinator:
    """
    Create and return an AgentCoordinator instance

    Args:
        db_config: Optional database configuration
        claude_api_key: Optional Claude API key

    Returns:
        Configured AgentCoordinator instance
    """
    return AgentCoordinator(db_config=db_config, claude_api_key=claude_api_key)


# Example usage for testing
if __name__ == "__main__":
    async def test_coordinator():
        """Test coordinator with sample jurisdiction"""
        # Configure logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )

        # Progress callback
        def progress_update(progress: int, message: str):
            print(f"[{progress}%] {message}")

        # Create coordinator
        coordinator = create_agent_coordinator()

        # Test jurisdiction
        test_jurisdiction_id = "550e8400-e29b-41d4-a716-446655440006"
        test_jurisdiction_name = "Test City, CO"

        print(f"\n{'='*60}")
        print(f"Testing AgentCoordinator for: {test_jurisdiction_name}")
        print(f"{'='*60}\n")

        # Run workflow
        result = await coordinator.load_codes_for_jurisdiction(
            jurisdiction_id=test_jurisdiction_id,
            jurisdiction_name=test_jurisdiction_name,
            jurisdiction_type="city",
            state="CO",
            progress_callback=progress_update
        )

        print(f"\n{'='*60}")
        print("Results:")
        print(f"{'='*60}")
        print(f"Success: {result['success']}")
        print(f"Rules Count: {result['rules_count']}")
        print(f"Sources Found: {result['sources_found']}")
        print(f"Sources Used: {result['sources_used']}")
        if 'error' in result:
            print(f"Error: {result['error']}")

    # Run test
    asyncio.run(test_coordinator())
