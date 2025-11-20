"""
Enhanced Rule Extractor with Claude Integration
Combines the original rule extractor with Claude AI for superior rule extraction
"""

import logging
from typing import Dict, List, Optional, Any
from rule_extractor import RuleExtractorAgent
from claude_integration import ClaudeRuleExtractor, ClaudeConfig

logger = logging.getLogger(__name__)

class EnhancedRuleExtractor:
    """Enhanced rule extractor that combines multiple extraction methods"""
    
    def __init__(self, claude_config: ClaudeConfig, llm_client=None):
        self.claude_extractor = ClaudeRuleExtractor(claude_config)
        self.fallback_extractor = RuleExtractorAgent(llm_client)
        
    async def extract_rules(self, section_text: str, section_ref: str, 
                          code_family: str, edition: str) -> List[Dict[str, Any]]:
        """
        Extract rules using Claude as primary method with fallback
        
        Args:
            section_text: Raw building code section text
            section_ref: Section reference
            code_family: Code family
            edition: Code edition
            
        Returns:
            List of extracted rules with confidence scores
        """
        try:
            # Try Claude extraction first
            claude_rules = await self.claude_extractor.extract_rules(
                section_text, section_ref, code_family, edition
            )
            
            if claude_rules and len(claude_rules) > 0:
                logger.info(f"Claude extracted {len(claude_rules)} rules from {section_ref}")
                return claude_rules
            
            # Fallback to traditional extraction
            logger.info(f"Claude extraction failed, using fallback for {section_ref}")
            fallback_rules = self.fallback_extractor.extract_rules(
                section_text, section_ref, code_family, edition
            )
            
            return fallback_rules
            
        except Exception as e:
            logger.error(f"Error in enhanced rule extraction: {e}")
            # Final fallback to basic extraction
            return self.fallback_extractor.extract_rules(
                section_text, section_ref, code_family, edition
            )
    
    async def extract_rules_batch(self, sections: List[Dict[str, str]]) -> List[Dict[str, Any]]:
        """
        Extract rules from multiple sections in batch
        
        Args:
            sections: List of section dictionaries with text, ref, family, edition
            
        Returns:
            Combined list of extracted rules
        """
        all_rules = []
        
        for section in sections:
            try:
                rules = await self.extract_rules(
                    section['text'],
                    section['ref'],
                    section['family'],
                    section['edition']
                )
                all_rules.extend(rules)
            except Exception as e:
                logger.error(f"Error extracting rules from {section['ref']}: {e}")
                continue
        
        return all_rules
    
    def validate_extracted_rules(self, rules: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Validate and clean extracted rules
        
        Args:
            rules: List of extracted rule dictionaries
            
        Returns:
            Validated and cleaned rules
        """
        validated_rules = []
        
        for rule in rules:
            # Validate rule structure
            if not self._validate_rule_structure(rule):
                logger.warning(f"Invalid rule structure: {rule}")
                continue
            
            # Clean and normalize rule data
            cleaned_rule = self._clean_rule_data(rule)
            
            # Calculate confidence score
            cleaned_rule['confidence'] = self._calculate_confidence(cleaned_rule)
            
            validated_rules.append(cleaned_rule)
        
        return validated_rules
    
    def _validate_rule_structure(self, rule: Dict[str, Any]) -> bool:
        """Validate rule has required structure"""
        required_fields = ['category', 'requirement', 'unit', 'value']
        
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
        
        return True
    
    def _clean_rule_data(self, rule: Dict[str, Any]) -> Dict[str, Any]:
        """Clean and normalize rule data"""
        cleaned = rule.copy()
        
        # Normalize units
        unit_mapping = {
            'inches': 'inch',
            'in': 'inch',
            'feet': 'ft',
            'ft': 'ft',
            'millimeters': 'mm',
            'mm': 'mm',
            'centimeters': 'cm',
            'cm': 'cm',
            'meters': 'm',
            'm': 'm'
        }
        
        if 'unit' in cleaned and cleaned['unit'] in unit_mapping:
            cleaned['unit'] = unit_mapping[cleaned['unit']]
        
        # Normalize category
        if 'category' in cleaned:
            cleaned['category'] = cleaned['category'].lower().replace(' ', '.')
        
        # Ensure conditions and exceptions are lists
        if 'conditions' not in cleaned:
            cleaned['conditions'] = []
        if 'exceptions' not in cleaned:
            cleaned['exceptions'] = []
        
        return cleaned
    
    def _calculate_confidence(self, rule: Dict[str, Any]) -> float:
        """Calculate confidence score for rule"""
        confidence = 0.5  # Base confidence
        
        # Increase confidence for clear numeric values
        if isinstance(rule.get('value'), (int, float)) and rule['value'] > 0:
            confidence += 0.2
        
        # Increase confidence for standard units
        standard_units = ['inch', 'ft', 'mm', 'cm', 'm', 'square feet', 'sq ft']
        if rule.get('unit') in standard_units:
            confidence += 0.1
        
        # Increase confidence for common categories
        common_categories = [
            'stairs.riser', 'stairs.tread', 'stairs.headroom',
            'railings.height', 'railings.spacing', 'railings.strength',
            'doors.width', 'doors.height', 'doors.clearance',
            'electrical.outlet_spacing', 'accessibility.ramp_slope'
        ]
        if rule.get('category') in common_categories:
            confidence += 0.1
        
        # Increase confidence for complete rule structure
        if rule.get('conditions') and len(rule['conditions']) > 0:
            confidence += 0.05
        if rule.get('exceptions') and len(rule['exceptions']) > 0:
            confidence += 0.05
        
        return min(confidence, 1.0)

# Factory function for easy initialization
def create_enhanced_extractor(claude_api_key: str = None) -> EnhancedRuleExtractor:
    """Create enhanced rule extractor with Claude integration"""
    import os
    
    api_key = claude_api_key or os.getenv('CLAUDE_API_KEY')
    if not api_key:
        raise ValueError("Claude API key is required")
    
    config = ClaudeConfig(api_key=api_key)
    return EnhancedRuleExtractor(config)