# AI Service - Memory Palace Intelligence Engine

**FastAPI service providing AI orchestration and processing capabilities powered by Gemma 3n**

## 🎯 Overview

This FastAPI service serves as the central AI intelligence of Memory Palace, with Google's Gemma 3n acting as the orchestrating director of a complete AI ecosystem. Rather than treating Gemma 3n as just another chatbot, we position it as the central intelligence that coordinates specialized AI services to create emotionally-aware memory experiences.

## 🏗️ Architecture

### Gemma 3n as Director

- **Memory Analysis**: Processing memories for anniversaries, seasonal relevance, emotional scoring
- **Conversation Orchestration**: Choosing between narrative responses and cinematic experiences
- **Proactive Intelligence**: Deciding when and how to surface memories
- **Context Understanding**: Recognizing relationships, emotions, and family dynamics

### Supporting AI Crew

- **Whisper**: Voice transcription and understanding
- **BLIP**: Visual scene comprehension and captioning
- **TTS (Coqui)**: Warm, natural speech synthesis
- **Vision**: Face detection and recognition
- **Embeddings**: Semantic memory search capabilities

## 🚀 Quick Start

### Prerequisites

```bash
# Python 3.9+
python --version

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull Gemma 3n model
ollama pull gemma3n:e2b
```

### Installation

```bash
cd AI/
pip install -r requirements.txt
```

### Configuration

```bash
# Create environment file
cp .env.example .env

# Edit configuration
nano .env
```

Required environment variables:

```env
OLLAMA_BASE_URL=http://localhost:11434
MODEL_NAME=gemma3n:e2b
AI_SERVICE_PORT=5000
AI_SERVICE_HOST=127.0.0.1
```

### Running the Service

```bash
# Development mode
python app.py

# Production mode
uvicorn app:app --host 0.0.0.0 --port 5000

# With auto-reload
uvicorn app:app --host 0.0.0.0 --port 5000 --reload
```

## 📋 API Endpoints

### Health Check

```http
GET /health
```

Returns service status and all AI component availability.

### Chat Orchestration

```http
POST /chat
Content-Type: application/json

{
  "query": "Tell me about happy memories",
  "context_memories": [
    {
      "memory_id": "123",
      "type": "photo",
      "description": "Family beach vacation..."
    }
  ],
  "patient_context": {
    "name": "Robert",
    "age": 78,
    "description": "Loving grandfather..."
  },
  "conversation_type": "memory_based"
}
```

**Response Types:**

- **Narrative**: Simple text response for conversation
- **Cinematic Show**: Full multimedia experience with scenes and narration

### Memory Analysis

```http
POST /analyze-memory
Content-Type: application/json

{
  "title": "Wedding Day",
  "description": "Our beautiful wedding ceremony",
  "type": "photo",
  "date": "1979-06-15",
  "location": "St. Mary's Church",
  "people_present": ["Robert", "Mary", "Father Johnson"]
}
```

**Response:**

```json
{
  "anniversary_type": "wedding",
  "seasonal_tags": ["summer", "wedding"],
  "proactive_score": 4.8,
  "reasoning": "Major life event with high emotional significance"
}
```

### Vector Embeddings

```http
POST /generate-embedding
Content-Type: application/json

{
  "text": "Family beach vacation with grandchildren playing in sand"
}
```

### Text-to-Speech

```http
POST /generate-speech
Content-Type: application/json

{
  "text": "Welcome back to this beautiful memory, dear."
}
```

Returns audio stream with duration metadata.

### Vision Processing

```http
POST /describe-image
Content-Type: multipart/form-data

file: [image_file]
```

### Audio Transcription

```http
POST /transcribe-audio
Content-Type: multipart/form-data

file: [audio_file]
```

### Face Recognition

```http
POST /recognize-people
Content-Type: application/json

{
  "photo_to_check_base64": "data:image/jpeg;base64,/9j/4AAQ...",
  "known_faces": [
    {
      "person_id": 1,
      "name": "Robert",
      "avatar_base64": "data:image/jpeg;base64,/9j/4AAQ..."
    }
  ]
}
```

## 🧠 AI Service Architecture

### Service Classes

#### ChatService

Handles conversation orchestration with Gemma 3n:

```python
class ChatService:
    def __init__(self):
        self.model_name = "gemma3n:e2b"
        self.client = ollama.Client()

    async def generate_response(self, request: ChatRequest) -> DirectorResponse:
        # Constructs specialized prompts for Gemma 3n
        # Returns narrative or cinematic responses
```

#### ProactiveAnalysisService

Memory analysis for proactive triggers:

```python
class ProactiveAnalysisService:
    async def analyze_memory(self, memory) -> AnalysisResult:
        # Uses Gemma 3n to analyze memory significance
        # Returns anniversary type, seasonal tags, proactive score
```

#### VisionService

Image understanding with BLIP:

```python
class VisionService:
    def __init__(self):
        self.model = BlipForConditionalGeneration.from_pretrained(
            "Salesforce/blip-image-captioning-base"
        )

    def generate_caption(self, image_bytes: bytes) -> str:
        # Generates natural language descriptions of images
```

#### EmbeddingService

Semantic vector generation:

```python
class EmbeddingService:
    def __init__(self):
        self.model_id = "sentence-transformers/all-MiniLM-L6-v2"

    def generate_embedding(self, text: str) -> List[float]:
        # Creates vector embeddings for semantic search
```

## 🔧 Advanced Configuration

### Model Optimization

```python
# AI service configuration
AI_CONFIG = {
    "gemma_temperature": 0.1,  # Consistent, focused responses
    "max_tokens": 1000,        # Sufficient for complex responses
    "embedding_threshold": 0.3, # Semantic similarity threshold
    "tts_quality": 0.8,        # Audio quality vs speed
    "vision_max_tokens": 50    # Caption length limit
}
```

### Memory Analysis Prompts

The service uses carefully crafted prompts to guide Gemma 3n's analysis:

```python
ANALYSIS_PROMPT = """
You are a memory analysis AI. Analyze the given memory for proactive trigger potential.

ANNIVERSARY TYPES: "work", "graduation", "birthday", "wedding", "anniversary", "retirement", "death"
SEASONAL TAGS: christmas, halloween, thanksgiving, birthday, vacation, summer, winter, etc.
PROACTIVE SCORE (0-5): 5 for major life events, 3 for holidays, 1 for casual events

Respond with ONLY a JSON object:
{
  "anniversary_type": "wedding",
  "seasonal_tags": ["summer", "wedding"],
  "proactive_score": 4.5,
  "reasoning": "Major life milestone with high emotional significance"
}
"""
```

### Conversation Orchestration

Gemma 3n uses different prompt strategies based on context:

- **Casual Conversation**: Simple, warm responses
- **Memory-Based Chat**: Rich context with family relationships
- **Cinematic Mode**: Multi-scene storytelling with visual memories
- **Proactive Triggers**: Pre-built emotional experiences

## 📊 Performance Considerations

### Resource Usage

- **Gemma 3n (via Ollama)**: ~4GB RAM for inference
- **BLIP Vision**: ~2GB GPU/CPU memory
- **Whisper**: ~1GB for audio processing
- **Total recommended**: 8GB+ RAM, GPU optional but beneficial

## 🔒 Security & Privacy

- **No external API calls**: All processing happens locally
- **No data persistence**: Services are stateless
- **Input validation**: All inputs sanitized and validated
- **Error sanitization**: No sensitive data in error messages

## 🧪 Testing

```bash
# Run health check
curl http://localhost:5000/health

# Test chat endpoint
curl -X POST http://localhost:5000/chat \
  -H "Content-Type: application/json" \
  -d '{"query": "Tell me a happy story"}'

# Test memory analysis
curl -X POST http://localhost:5000/analyze-memory \
  -H "Content-Type: application/json" \
  -d '{"title": "Birthday Party", "type": "photo"}'
```

## 🐛 Troubleshooting

### Common Issues

**Ollama Connection Failed**

```bash
# Check Ollama status
ollama list

# Restart Ollama
sudo systemctl restart ollama

# Verify model exists
ollama pull gemma3n:e2b
```

**GPU Memory Issues**

```python
# Force CPU mode in environment
export CUDA_VISIBLE_DEVICES=""

# Or configure in service
torch_dtype = torch.float32  # Instead of float16
```

**Service Startup Slow**

- First model load takes time (downloading/caching)
- Subsequent starts are much faster
- Consider preloading models in production
