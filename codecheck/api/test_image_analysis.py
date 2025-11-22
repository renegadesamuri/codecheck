import asyncio
from unittest.mock import MagicMock, patch, AsyncMock
import json
import os
from claude_service import ClaudeService

async def test_image_analysis():
    print("Testing Image Analysis Feature...")
    
    # Mock Anthropic client
    with patch('claude_service.AsyncAnthropic') as MockAnthropic:
        mock_client = MockAnthropic.return_value
        
        # Mock response
        mock_response = MagicMock()
        mock_content = MagicMock()
        mock_content.text = json.dumps({
            "summary": "A wooden staircase with missing handrail",
            "elements_detected": ["stairs", "wall"],
            "potential_violations": [
                {
                    "element": "Stair Handrail",
                    "issue": "Missing handrail",
                    "code_reference": "IRC R311.7.8",
                    "severity": "high",
                    "confidence": 0.95,
                    "explanation": "Handrail required."
                }
            ],
            "observations": ["Workmanship looks okay otherwise"],
            "overall_status": "fail"
        })
        mock_response.content = [mock_content]
        
        # Use AsyncMock for create
        mock_client.messages.create = AsyncMock(return_value=mock_response)
        
        # Initialize service (will use mock client)
        with patch.dict(os.environ, {"CLAUDE_API_KEY": "mock_key"}):
            service = ClaudeService()
        
        # Test data
        image_data = "base64_encoded_image_data_placeholder"
        context = {"jurisdiction": "San Francisco, CA"}
        
        print("Calling analyze_image...")
        try:
            result = await service.analyze_image(image_data, context=context)
            
            print("\nResult:")
            print(json.dumps(result, indent=2))
            
            if result['overall_status'] == 'fail' and len(result['potential_violations']) > 0:
                print("\nSUCCESS: Image analysis parsed correctly.")
            else:
                print("\nFAILURE: Unexpected result.")
        except Exception as e:
            print(f"\nFAILURE: Exception occurred: {e}")
            if hasattr(e, 'detail'):
                print(f"Detail: {e.detail}")

if __name__ == "__main__":
    asyncio.run(test_image_analysis())
