"""
Claude AI Service for CodeCheck API
Integrates Claude AI for rule extraction and conversational responses
"""

import os
import json
from typing import Dict, List, Optional, Any
from fastapi import HTTPException
import asyncio
from anthropic import Anthropic

class ClaudeService:
    """Service for Claude AI integration in the API"""
    
    def __init__(self):
        self.api_key = os.getenv('CLAUDE_API_KEY')
        if not self.api_key:
            raise HTTPException(
                status_code=500, 
                detail="Claude API key not configured"
            )
        
        self.client = Anthropic(api_key=self.api_key)
        self.model = "claude-3-5-sonnet-20241022"
    
    async def extract_rules_from_text(self, section_text: str, section_ref: str, 
                                    code_family: str, edition: str) -> List[Dict[str, Any]]:
        """
        Extract structured rules from building code text using Claude
        
        Args:
            section_text: Raw building code section text
            section_ref: Section reference (e.g., 'IRC R311.7.2')
            code_family: Code family (e.g., 'IRC', 'IBC')
            edition: Code edition (e.g., '2021')
            
        Returns:
            List of extracted rule dictionaries
        """
        try:
            prompt = self._create_rule_extraction_prompt(
                section_text, section_ref, code_family, edition
            )
            
            response = await self.client.messages.create(
                model=self.model,
                max_tokens=4000,
                temperature=0.1,
                messages=[{
                    "role": "user",
                    "content": prompt
                }]
            )
            
            # Parse Claude's response
            content = response.content[0].text
            rules = self._parse_rule_response(content)
            
            # Validate and enhance rules
            validated_rules = []
            for rule in rules:
                if self._validate_rule(rule):
                    rule['confidence'] = self._calculate_confidence(rule, section_text)
                    rule['section_ref'] = section_ref
                    rule['edition'] = edition
                    rule['code_family'] = code_family
                    validated_rules.append(rule)
            
            return validated_rules
            
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"Error extracting rules with Claude: {str(e)}"
            )
    
    async def generate_explanation(self, rule: Dict[str, Any], 
                                 measurement_value: float = None) -> str:
        """
        Generate plain-English explanation of a building code rule
        
        Args:
            rule: Rule dictionary with JSON structure
            measurement_value: Optional measured value for comparison
            
        Returns:
            Plain-English explanation
        """
        try:
            prompt = self._create_explanation_prompt(rule, measurement_value)
            
            response = await self.client.messages.create(
                model=self.model,
                max_tokens=2000,
                temperature=0.3,
                messages=[{
                    "role": "user",
                    "content": prompt
                }]
            )
            
            return response.content[0].text
            
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"Error generating explanation: {str(e)}"
            )
    
    async def generate_conversational_response(self, user_message: str, 
                                             context: Dict[str, Any] = None) -> str:
        """
        Generate conversational response for the AI assistant
        
        Args:
            user_message: User's input message
            context: Additional context (project info, measurements, etc.)
            
        Returns:
            Claude's response message
        """
        try:
            system_prompt = self._create_system_prompt(context)
            
            response = await self.client.messages.create(
                model=self.model,
                max_tokens=2000,
                temperature=0.7,
                system=system_prompt,
                messages=[{
                    "role": "user",
                    "content": user_message
                }]
            )
            
            return response.content[0].text
            
        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"Error generating conversational response: {str(e)}"
            )
    
    def _create_rule_extraction_prompt(self, section_text: str, section_ref: str, 
                                     code_family: str, edition: str) -> str:
        """Create optimized prompt for rule extraction"""
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
    
    def _create_explanation_prompt(self, rule: Dict[str, Any], 
                                 measurement_value: float = None) -> str:
        """Create prompt for rule explanation"""
        rule_json = rule.get('rule_json', {})
        category = rule_json.get('category', 'unknown')
        requirement = rule_json.get('requirement', 'unknown')
        unit = rule_json.get('unit', 'unknown')
        value = rule_json.get('value', 'unknown')
        
        prompt = f"""Explain this building code requirement in plain English:

Category: {category}
Requirement: {requirement}
Unit: {unit}
Value: {value}
Section: {rule.get('section_ref', 'unknown')}

"""
        
        if measurement_value is not None:
            prompt += f"Measured Value: {measurement_value} {unit}\n\n"
            prompt += "Include whether the measurement passes or fails the requirement.\n"
        
        prompt += """Provide a clear, helpful explanation that:
1. Explains what the requirement means in practical terms
2. Describes why this requirement exists (safety, accessibility, etc.)
3. Gives specific guidance on how to comply
4. Mentions any important exceptions or conditions
5. Is written for both DIYers and professionals

Keep the explanation concise but comprehensive."""
        
        return prompt
    
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
    
    def _parse_rule_response(self, response_text: str) -> List[Dict[str, Any]]:
        """Parse Claude's rule extraction response"""
        try:
            # Find JSON array in response
            start_idx = response_text.find('[')
            end_idx = response_text.rfind(']') + 1
            
            if start_idx == -1 or end_idx == 0:
                return []
            
            json_str = response_text[start_idx:end_idx]
            rules = json.loads(json_str)
            
            if not isinstance(rules, list):
                return []
            
            return rules
            
        except json.JSONDecodeError:
            return []
        except Exception:
            return []
    
    def _validate_rule(self, rule: Dict[str, Any]) -> bool:
        """Validate rule structure"""
        required_fields = ['category', 'requirement', 'unit', 'value']
        
        for field in required_fields:
            if field not in rule:
                return False
        
        if rule['requirement'] not in ['min', 'max', 'exact', 'range']:
            return False
        
        try:
            float(rule['value'])
        except (ValueError, TypeError):
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
        
        return min(confidence, 1.0)

# Global instance
claude_service = None

def get_claude_service() -> ClaudeService:
    """Get or create Claude service instance"""
    global claude_service
    if claude_service is None:
        claude_service = ClaudeService()
    return claude_service