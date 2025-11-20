"""
Claude AI Integration for CodeCheck
Provides LLM-powered rule extraction and conversational AI capabilities
"""

import os
import json
import logging
from typing import Dict, List, Optional, Any
from anthropic import Anthropic
import asyncio
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class ClaudeConfig:
    """Configuration for Claude API"""
    api_key: str
    model: str = "claude-3-5-sonnet-20241022"
    max_tokens: int = 4000
    temperature: float = 0.1

class ClaudeRuleExtractor:
    """Claude-powered rule extraction from building code text"""
    
    def __init__(self, config: ClaudeConfig):
        self.client = Anthropic(api_key=config.api_key)
        self.config = config
        
    async def extract_rules(self, section_text: str, section_ref: str, 
                          code_family: str, edition: str) -> List[Dict[str, Any]]:
        """
        Extract structured rules using Claude
        
        Args:
            section_text: Raw building code section text
            section_ref: Section reference (e.g., 'IRC R311.7.2')
            code_family: Code family (e.g., 'IRC', 'IBC')
            edition: Code edition (e.g., '2021')
            
        Returns:
            List of extracted rule dictionaries
        """
        try:
            prompt = self._create_extraction_prompt(section_text, section_ref, code_family, edition)
            
            response = await self.client.messages.create(
                model=self.config.model,
                max_tokens=self.config.max_tokens,
                temperature=self.config.temperature,
                messages=[{
                    "role": "user",
                    "content": prompt
                }]
            )
            
            # Parse Claude's response
            content = response.content[0].text
            rules = self._parse_response(content)
            
            # Validate and score rules
            validated_rules = []
            for rule in rules:
                if self._validate_rule(rule):
                    rule['confidence'] = self._calculate_confidence(rule, section_text)
                    rule['section_ref'] = section_ref
                    rule['edition'] = edition
                    rule['code_family'] = code_family
                    validated_rules.append(rule)
                else:
                    logger.warning(f"Invalid rule extracted: {rule}")
            
            logger.info(f"Claude extracted {len(validated_rules)} valid rules from {section_ref}")
            return validated_rules
            
        except Exception as e:
            logger.error(f"Error extracting rules with Claude: {e}")
            return []
    
    def _create_extraction_prompt(self, section_text: str, section_ref: str, 
                                 code_family: str, edition: str) -> str:
        """Create optimized prompt for Claude"""
        return f"""You are an expert building code analyst. Extract measurable, machine-actionable rules from the provided building code section.

CRITICAL INSTRUCTIONS:
1. Extract ONLY measurable requirements (dimensions, counts, ratios, etc.)
2. Normalize all measurements to standard units (inch, ft, mm, cm, m)
3. Identify the requirement type (min, max, exact, range)
4. Include any conditions or exceptions
5. Do not hallucinate - only extract what is explicitly stated
6. Return valid JSON array format

OUTPUT FORMAT (JSON array):
[
  {{
    "category": "stairs.tread",
    "requirement": "min",
    "unit": "inch", 
    "value": 11.0,
    "conditions": [{{"occupancy": "R-2"}}],
    "exceptions": ["spiral stairways"],
    "notes": "Local amendment increases to 11.5 in downtown core"
  }}
]

COMMON CATEGORIES:
- stairs.riser, stairs.tread, stairs.headroom, stairs.width
- railings.height, railings.spacing, railings.strength
- doors.width, doors.height, doors.clearance
- electrical.outlet_spacing, electrical.gfci_requirements
- accessibility.ramp_slope, accessibility.door_width

Section Reference: {section_ref}
Code Family: {code_family}
Edition: {edition}

Section Text:
{section_text}

Extract rules now:"""
    
    def _parse_response(self, response_text: str) -> List[Dict[str, Any]]:
        """Parse Claude's response into rule dictionaries"""
        try:
            # Find JSON array in response
            start_idx = response_text.find('[')
            end_idx = response_text.rfind(']') + 1
            
            if start_idx == -1 or end_idx == 0:
                logger.warning("No JSON array found in Claude response")
                return []
            
            json_str = response_text[start_idx:end_idx]
            rules = json.loads(json_str)
            
            if not isinstance(rules, list):
                logger.warning("Claude response is not a JSON array")
                return []
            
            return rules
            
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing Claude JSON response: {e}")
            return []
        except Exception as e:
            logger.error(f"Unexpected error parsing Claude response: {e}")
            return []
    
    def _validate_rule(self, rule: Dict[str, Any]) -> bool:
        """Validate rule structure and content"""
        required_fields = ['category', 'requirement', 'unit', 'value']
        
        # Check required fields
        for field in required_fields:
            if field not in rule:
                logger.warning(f"Missing required field: {field}")
                return False
        
        # Validate requirement type
        if rule['requirement'] not in ['min', 'max', 'exact', 'range']:
            logger.warning(f"Invalid requirement type: {rule['requirement']}")
            return False
        
        # Validate value is numeric
        try:
            float(rule['value'])
        except (ValueError, TypeError):
            logger.warning(f"Invalid value: {rule['value']}")
            return False
        
        # Validate unit
        if not isinstance(rule['unit'], str) or len(rule['unit']) == 0:
            logger.warning(f"Invalid unit: {rule['unit']}")
            return False
        
        return True
    
    def _calculate_confidence(self, rule: Dict[str, Any], section_text: str) -> float:
        """Calculate confidence score for extracted rule"""
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
        
        # Increase confidence if section text contains the value
        if str(rule.get('value')) in section_text:
            confidence += 0.1
        
        # Increase confidence for complete rule structure
        if rule.get('conditions') is not None:
            confidence += 0.05
        if rule.get('exceptions') is not None:
            confidence += 0.05
        
        return min(confidence, 1.0)

class ClaudeConversationalAI:
    """Claude-powered conversational AI for construction compliance guidance"""
    
    def __init__(self, config: ClaudeConfig):
        self.client = Anthropic(api_key=config.api_key)
        self.config = config
        
    async def generate_response(self, user_message: str, context: Dict[str, Any] = None) -> str:
        """
        Generate conversational response using Claude
        
        Args:
            user_message: User's input message
            context: Additional context (project info, measurements, etc.)
            
        Returns:
            Claude's response message
        """
        try:
            system_prompt = self._create_system_prompt(context)
            
            response = await self.client.messages.create(
                model=self.config.model,
                max_tokens=self.config.max_tokens,
                temperature=0.7,  # Higher temperature for conversational responses
                system=system_prompt,
                messages=[{
                    "role": "user",
                    "content": user_message
                }]
            )
            
            return response.content[0].text
            
        except Exception as e:
            logger.error(f"Error generating Claude response: {e}")
            return "I'm sorry, I'm having trouble processing your request right now. Please try again."
    
    def _create_system_prompt(self, context: Dict[str, Any] = None) -> str:
        """Create system prompt for conversational AI"""
        base_prompt = """You are CodeCheck AI, an expert construction compliance assistant. You help users understand building codes and verify compliance through measurements.

YOUR ROLE:
- Provide clear, accurate building code guidance
- Explain requirements in plain English
- Suggest next steps for compliance verification
- Help interpret measurement results
- Guide users through the compliance process

COMMUNICATION STYLE:
- Professional but approachable
- Use clear, non-technical language when possible
- Provide specific, actionable advice
- Ask clarifying questions when needed
- Be encouraging and supportive

EXPERTISE AREAS:
- Building codes (IRC, IBC, NEC, ADA)
- Construction measurements and calculations
- Inspection requirements and procedures
- Permit applications and processes
- Code compliance verification

IMPORTANT:
- Always recommend consulting with local building officials for final approval
- Provide code citations when relevant
- Suggest taking photos for documentation
- Emphasize safety considerations"""
        
        if context:
            context_info = f"\nCURRENT CONTEXT:\n"
            for key, value in context.items():
                context_info += f"- {key}: {value}\n"
            base_prompt += context_info
        
        return base_prompt

class ClaudeAmendmentAnalyzer:
    """Claude-powered analysis of local code amendments"""
    
    def __init__(self, config: ClaudeConfig):
        self.client = Anthropic(api_key=config.api_key)
        self.config = config
        
    async def analyze_amendment(self, base_text: str, amendment_text: str, 
                              section_ref: str) -> Dict[str, Any]:
        """
        Analyze local amendment against base code
        
        Args:
            base_text: Base code section text
            amendment_text: Local amendment text
            section_ref: Section reference
            
        Returns:
            Analysis with changes and impact
        """
        try:
            prompt = f"""Analyze this local building code amendment against the base code section.

BASE CODE ({section_ref}):
{base_text}

LOCAL AMENDMENT:
{amendment_text}

Provide analysis in JSON format:
{{
  "change_type": "add|replace|delete|modify",
  "impact": "description of what changed",
  "new_requirement": "extracted rule if applicable",
  "effective_date": "date if mentioned",
  "notes": "additional context or warnings"
}}

Focus on measurable changes that affect compliance requirements."""

            response = await self.client.messages.create(
                model=self.config.model,
                max_tokens=self.config.max_tokens,
                temperature=self.config.temperature,
                messages=[{
                    "role": "user",
                    "content": prompt
                }]
            )
            
            # Parse response
            content = response.content[0].text
            analysis = self._parse_amendment_analysis(content)
            
            return analysis
            
        except Exception as e:
            logger.error(f"Error analyzing amendment: {e}")
            return {
                "change_type": "unknown",
                "impact": "Unable to analyze amendment",
                "new_requirement": None,
                "effective_date": None,
                "notes": f"Analysis error: {str(e)}"
            }
    
    def _parse_amendment_analysis(self, response_text: str) -> Dict[str, Any]:
        """Parse amendment analysis response"""
        try:
            # Find JSON in response
            start_idx = response_text.find('{')
            end_idx = response_text.rfind('}') + 1
            
            if start_idx == -1 or end_idx == 0:
                return {"error": "No JSON found in response"}
            
            json_str = response_text[start_idx:end_idx]
            return json.loads(json_str)
            
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing amendment analysis: {e}")
            return {"error": f"JSON parse error: {str(e)}"}

# Factory function for easy initialization
def create_claude_integration(api_key: str = None) -> Dict[str, Any]:
    """Create Claude integration components"""
    api_key = api_key or os.getenv('CLAUDE_API_KEY')
    
    if not api_key:
        raise ValueError("Claude API key is required")
    
    config = ClaudeConfig(api_key=api_key)
    
    return {
        'rule_extractor': ClaudeRuleExtractor(config),
        'conversational_ai': ClaudeConversationalAI(config),
        'amendment_analyzer': ClaudeAmendmentAnalyzer(config)
    }