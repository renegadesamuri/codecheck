"""
Rule Extractor Agent
LLM-assisted extraction of structured rules from building code text
"""

import json
import logging
from typing import Dict, List, Optional, Any
import os

logger = logging.getLogger(__name__)

class RuleExtractorAgent:
    """Agent for extracting structured rules from building code text using LLM"""
    
    def __init__(self, llm_client=None):
        self.llm_client = llm_client
        self.rule_schema = {
            "category": "string (e.g., 'stairs.tread', 'railings.height')",
            "requirement": "string (min, max, exact, range)",
            "unit": "string (inch, ft, mm, etc.)",
            "value": "number",
            "conditions": "array of condition objects",
            "exceptions": "array of exception strings",
            "section_ref": "string (e.g., 'IRC R311.7.2')",
            "edition": "string (e.g., '2021')",
            "code_family": "string (e.g., 'IRC', 'IBC')"
        }
    
    def extract_rules(self, section_text: str, section_ref: str, 
                     code_family: str, edition: str) -> List[Dict[str, Any]]:
        """
        Extract structured rules from building code section text
        
        Args:
            section_text: Raw text of the building code section
            section_ref: Reference to the section (e.g., 'IRC R311.7.2')
            code_family: Code family (e.g., 'IRC', 'IBC')
            edition: Code edition (e.g., '2021')
            
        Returns:
            List of extracted rule dictionaries
        """
        try:
            # Create the extraction prompt
            prompt = self._create_extraction_prompt(section_text, section_ref, code_family, edition)
            
            # For now, use mock extraction - replace with actual LLM call
            if self.llm_client:
                response = self.llm_client.generate(prompt)
                rules = self._parse_llm_response(response)
            else:
                # Mock extraction for testing
                rules = self._mock_extraction(section_text, section_ref, code_family, edition)
            
            # Validate extracted rules
            validated_rules = []
            for rule in rules:
                if self._validate_rule(rule):
                    validated_rules.append(rule)
                else:
                    logger.warning(f"Invalid rule extracted: {rule}")
            
            logger.info(f"Extracted {len(validated_rules)} valid rules from {section_ref}")
            return validated_rules
            
        except Exception as e:
            logger.error(f"Error extracting rules from {section_ref}: {e}")
            return []
    
    def _create_extraction_prompt(self, section_text: str, section_ref: str, 
                                 code_family: str, edition: str) -> str:
        """Create the LLM prompt for rule extraction"""
        return f"""
You are a building-code parser. Extract atomic, machine-actionable rules from the provided section.

Output only JSON that conforms to this schema:
{json.dumps(self.rule_schema, indent=2)}

Guidelines:
- Normalize measurements to standard units (inch, ft, mm)
- Extract only measurable requirements (dimensions, counts, etc.)
- Include conditions and exceptions
- Do not hallucinate - only extract what is explicitly stated
- If no measurable rules found, return empty array []

Section Reference: {section_ref}
Code Family: {code_family}
Edition: {edition}

Section Text:
{section_text}
"""
    
    def _parse_llm_response(self, response: str) -> List[Dict[str, Any]]:
        """Parse LLM response into rule dictionaries"""
        try:
            # Extract JSON from response
            json_start = response.find('[')
            json_end = response.rfind(']') + 1
            if json_start != -1 and json_end != -1:
                json_str = response[json_start:json_end]
                return json.loads(json_str)
            return []
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing LLM response: {e}")
            return []
    
    def _mock_extraction(self, section_text: str, section_ref: str, 
                        code_family: str, edition: str) -> List[Dict[str, Any]]:
        """Mock rule extraction for testing purposes"""
        mock_rules = []
        
        # Simple pattern matching for common requirements
        text_lower = section_text.lower()
        
        # Stair riser height
        if 'riser' in text_lower and ('height' in text_lower or 'maximum' in text_lower):
            mock_rules.append({
                "category": "stairs.riser",
                "requirement": "max",
                "unit": "inch",
                "value": 7.75,
                "conditions": [],
                "exceptions": [],
                "section_ref": section_ref,
                "edition": edition,
                "code_family": code_family
            })
        
        # Stair tread depth
        if 'tread' in text_lower and ('depth' in text_lower or 'minimum' in text_lower):
            mock_rules.append({
                "category": "stairs.tread",
                "requirement": "min",
                "unit": "inch",
                "value": 11.0,
                "conditions": [],
                "exceptions": [],
                "section_ref": section_ref,
                "edition": edition,
                "code_family": code_family
            })
        
        # Guard rail height
        if 'guard' in text_lower and ('height' in text_lower or 'minimum' in text_lower):
            mock_rules.append({
                "category": "railings.height",
                "requirement": "min",
                "unit": "inch",
                "value": 36.0,
                "conditions": [],
                "exceptions": [],
                "section_ref": section_ref,
                "edition": edition,
                "code_family": code_family
            })
        
        # Guard rail spacing
        if 'spacing' in text_lower and ('baluster' in text_lower or 'guard' in text_lower):
            mock_rules.append({
                "category": "railings.spacing",
                "requirement": "max",
                "unit": "inch",
                "value": 4.0,
                "conditions": [],
                "exceptions": [],
                "section_ref": section_ref,
                "edition": edition,
                "code_family": code_family
            })
        
        return mock_rules
    
    def _validate_rule(self, rule: Dict[str, Any]) -> bool:
        """Validate that a rule conforms to the expected schema"""
        required_fields = ['category', 'requirement', 'unit', 'value']
        
        # Check required fields
        for field in required_fields:
            if field not in rule:
                return False
        
        # Validate requirement type
        if rule['requirement'] not in ['min', 'max', 'exact', 'range']:
            return False
        
        # Validate value is numeric
        try:
            float(rule['value'])
        except (ValueError, TypeError):
            return False
        
        # Validate unit is string
        if not isinstance(rule['unit'], str):
            return False
        
        return True
    
    def calculate_confidence(self, rule: Dict[str, Any], section_text: str) -> float:
        """
        Calculate confidence score for an extracted rule
        
        Args:
            rule: Extracted rule dictionary
            section_text: Original section text
            
        Returns:
            Confidence score between 0.0 and 1.0
        """
        confidence = 0.5  # Base confidence
        
        # Increase confidence for clear numeric values
        if isinstance(rule.get('value'), (int, float)):
            confidence += 0.2
        
        # Increase confidence for standard units
        standard_units = ['inch', 'ft', 'mm', 'cm', 'm']
        if rule.get('unit') in standard_units:
            confidence += 0.1
        
        # Increase confidence for common categories
        common_categories = ['stairs.riser', 'stairs.tread', 'railings.height', 'railings.spacing']
        if rule.get('category') in common_categories:
            confidence += 0.1
        
        # Increase confidence if section text contains the value
        if str(rule.get('value')) in section_text:
            confidence += 0.1
        
        return min(confidence, 1.0)