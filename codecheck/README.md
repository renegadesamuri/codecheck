# CodeCheck: AI-Powered Construction Compliance Assistant

A revolutionary construction compliance application that combines LiDAR/AR measurement technology with AI-powered code verification and automated inspection scheduling.

## Features

- **AI-Assisted Conversational UI:** Natural language guidance through compliance requirements
- **LiDAR/AR Measurement:** Precise measurements using iPhone LiDAR technology
- **Multi-Jurisdictional Database:** PostGIS-based with geo-boundary lookups
- **Automated Code Harvesting:** 10-agent system for real-time code updates
- **Flexible Rule Engine:** JSONB structure with confidence scoring

## Architecture

### Database Layer
- PostgreSQL + PostGIS for spatial queries
- Custom schema with jurisdictions, code adoptions, amendments, and rules
- JSONB-based flexible rule engine

### API Layer
- FastAPI backend with RESTful endpoints
- Real-time compliance checking
- Jurisdiction resolution via PostGIS

### Agent System
- 10 specialized agents for automated code harvesting
- LLM-assisted rule extraction
- Change detection and monitoring

### iOS App
- SwiftUI + ARKit for measurements
- Conversational AI interface
- Real-time compliance checking

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Python 3.11+
- Xcode 15+ (for iOS development)
- Claude API key (for AI features)

### Environment Setup

1. Copy environment template:
```bash
cp .env.example .env
```

2. Add your Claude API key to `.env`:
```bash
CLAUDE_API_KEY=your_claude_api_key_here
```

### Database Setup

1. Start the database:
```bash
docker-compose up postgres -d
```

2. Initialize the schema:
```bash
cd database
pip install -r requirements.txt
python setup.py
```

### API Development

1. Start the API server:
```bash
cd api
pip install -r requirements.txt
uvicorn main:app --reload
```

2. Test the API:
```bash
curl http://localhost:8000/
```

### iOS Development

1. Open the iOS project in Xcode:
```bash
open ios-app/CodeCheck.xcodeproj
```

2. Build and run on simulator or device

## API Endpoints

### Core Endpoints

- `POST /resolve` - Resolve coordinates to jurisdictions
- `POST /codeset` - Get adopted codes for jurisdiction
- `POST /rules/query` - Query rules by category
- `POST /check` - Check compliance against measurements

### AI-Powered Endpoints

- `POST /explain` - Generate plain-English rule explanations using Claude
- `POST /conversation` - Conversational AI responses
- `POST /extract-rules` - Extract structured rules from code text using Claude

### Example Usage

```python
import requests

# Resolve jurisdiction
response = requests.post('http://localhost:8000/resolve', json={
    'latitude': 39.7392,
    'longitude': -104.9903
})
jurisdictions = response.json()['jurisdictions']

# Query rules
response = requests.post('http://localhost:8000/rules/query', json={
    'jurisdiction_id': jurisdictions[0]['id'],
    'category': 'stairs.tread'
})
rules = response.json()['rules']

# Check compliance
response = requests.post('http://localhost:8000/check', json={
    'jurisdiction_id': jurisdictions[0]['id'],
    'metrics': {'stair_tread_in': 10.75}
})
result = response.json()
```

## Agent System

### Jurisdiction-Finder Agent
Finds jurisdictions for given coordinates using PostGIS spatial queries.

### Rule Extractor Agent
LLM-assisted extraction of structured rules from building code text.

### Source-Discovery Harvester
Automated discovery of official code adoption pages and ordinance libraries.

### Document Fetcher
Fetches and processes building code documents with change detection.

## Development Status

- [x] Database schema and setup
- [x] API foundation with core endpoints
- [x] Agent system architecture
- [x] iOS app foundation
- [ ] LLM integration
- [ ] Automated code harvesting
- [ ] Production deployment

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is proprietary software. All rights reserved.

## Support

For questions or support, please contact the development team.