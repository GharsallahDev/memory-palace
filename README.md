# **Memory Palace 🧠✨**

**A Private, AI-Powered Family Memory System**

[![Competition](https://img.shields.io/badge/Google-Gemma%203n%20Challenge-blue)](https://kaggle.com/competitions/google-gemma-3n-hackathon)
[![License](https://img.shields.io/badge/License-CC%20BY%204.0-green.svg)](LICENSE)
[![Ollama](https://img.shields.io/badge/Powered%20by-Ollama-orange)](https://ollama.ai)

> _Bridging the gap between memory and love for 55+ million people living with dementia worldwide._

## 🎯 Overview

Memory Palace is a complete ecosystem that helps families preserve and share memories with elderly relatives experiencing memory loss. Using Google's **Gemma 3n as the central orchestrating intelligence**, it creates proactive, emotionally-aware experiences that help users reconnect with the moments that define them.

### ✨ Key Features

- **🏠 Private & Local**: All processing happens in your home network
- **👨‍👩‍👧‍👦 Family Ecosystem**: Multiple family members contribute memories via iOS app
- **🎭 Cinematic Experiences**: AI-generated memory journeys with synchronized narration
- **⚡ Proactive Triggers**: "On this day" and anniversary memory surfacing
- **🎯 Multi-Modal**: Photos, videos, voice recordings, and text notes
- **🧠 Intelligent Search**: Vector-based semantic memory retrieval
- **💝 Emotional AI**: Understanding relationships and context

## 🏗️ Architecture

Memory Palace consists of four main components working in harmony:

```
┌─────────────────┐    ┌─────────────────┐
│   iOS Mobile    │    │    React Web    │
│  Family Upload  │    │Patient Interface│
└─────────┬───────┘    └─────────┬───────┘
          │                      │
          └──────────┬───────────┘
                     │
         ┌───────────▼────────────┐
         │     Node.js Hub        │
         │  Memory Management     │
         │   WebSocket Server     │
         └───────────┬────────────┘
                     │
         ┌───────────▼────────────┐
         │    FastAPI + AI        │
         │  Gemma 3n Director     │
         │   Specialized Crew     │
         └────────────────────────┘
```

### 🎼 Gemma 3n as Orchestra Director

Rather than using Gemma 3n as just another chatbot, we positioned it as the **central intelligence** that orchestrates a complete AI experience:

- **🎯 Memory Analysis**: Anniversary detection, seasonal tagging, emotional scoring
- **🎬 Conversation Direction**: Choosing between narrative responses and cinematic shows
- **⚡ Proactive Intelligence**: Deciding when and how to surface memories
- **💭 Context Understanding**: Recognizing relationships, emotions, and family dynamics

**Supporting AI Crew:**

- **Whisper**: Voice transcription and understanding
- **BLIP**: Visual scene comprehension and captioning
- **TTS (Coqui)**: Warm, natural speech synthesis
- **Vision Framework**: On-device face detection and recognition

## 🚀 Quick Start

### Prerequisites

- macOS/Linux with Docker
- Node.js 18+
- Python 3.9+
- iOS device for family uploads (optional)

### 1. Clone Repository

```bash
git clone https://github.com/GharsallahDev/memory-palace.git
cd memory-palace
```

### 2. Install Ollama

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull Gemma 3n model
ollama pull gemma3n:e2b
```

### 3. Set Up Applications

```bash
# Follow the guides in READMEs
```

### 4. Access Your Memory Palace

- **Family Hub Dashboard**: http://localhost:3000
- **Patient Interface**: http://localhost:3000 → "Enter Your Palace"
- **iOS App Setup**: Scan QR code from dashboard

## 📂 Repository Structure

```
memory-palace/
├── README.md                 # You are here! Main project overview and setup.
├── LICENSE                   # CC BY 4.0 License
├── AI/                       # FastAPI + Gemma 3n service
├── BACKEND/                  # Node.js family hub
├── FRONTEND/                 # React patient interface
├── MOBILE/                   # iOS family app
└── docs/                     # Detailed architectural diagrams
```

## 📱 Component Guide

### [🤖 AI Service](AI)

FastAPI service providing AI capabilities:

- Gemma 3n conversation orchestration
- Memory analysis and proactive triggers
- Multi-modal processing pipeline
- Vector embeddings and semantic search

### [🏠 Backend Hub](BACKEND)

Node.js server managing the family ecosystem:

- Memory storage and management
- Real-time WebSocket communication
- Background processing workers
- Family member coordination

### [🌐 Web Interface](FRONTEND)

React application for elderly users:

- Cinematic memory experiences
- Voice and text conversation
- Proactive memory notifications
- Gentle, accessible design

### [📱 iOS App](MOBILE)

Native Swift application for family members:

- Multi-modal memory capture
- On-device face detection
- Rich metadata entry
- Seamless server synchronization

## 🛠️ Technical Deep Dive

### Privacy-First Architecture

All processing happens locally on your home network. No memories are ever sent to external cloud services.

### Proactive Memory Intelligence

The system automatically:

1. **Analyzes uploaded memories** for anniversaries and seasonal relevance
2. **Generates vector embeddings** for semantic search capabilities
3. **Creates proactive triggers** based on dates and emotional significance
4. **Builds cinematic experiences** when multiple related memories are found

### Face Recognition Pipeline

1. **Perceptual hash matching** for exact duplicate detection
2. **On-device face detection** using Apple's Vision framework
3. **Semantic people search** for related memories
4. **Automatic avatar generation** from tagged faces

### Real-Time Family Coordination

- **WebSocket communication** for instant memory sharing
- **Offline queuing** for disconnected family members
- **Conflict resolution** for simultaneous edits
- **Background synchronization** across all devices

## 🎯 Impact & Results

### Solving Real Problems

- **55+ million people** worldwide live with dementia
- **Families struggle** to help loved ones remember
- **Existing solutions** lack emotional intelligence and family coordination
- **Privacy concerns** prevent cloud-based alternatives

### Technical Achievements

- **Complete production-ready system** deployable in 5 minutes
- **Advanced AI orchestration** with Gemma 3n as central intelligence
- **Multi-modal understanding** across text, voice, photos, and video
- **Real-time proactive experiences** that surprise and delight users

## 🏆 Competition Alignment

**Built for Google Gemma 3n Impact Challenge:**

- **✅ Ollama Integration**: Perfect showcase of Gemma 3n via Ollama
- **✅ Real-World Impact**: Addresses critical healthcare challenge
- **✅ Privacy-First**: Local processing, no cloud dependencies
- **✅ Technical Innovation**: AI orchestration beyond simple chatbots
- **✅ Production Ready**: Complete ecosystem, not just prototype

## 📋 Documentation

- [🖼️ Architectural Diagrams](DOCS/)
- [🤖 AI Service Guide](AI/README.md)
- [🏠 Backend Hub Guide](BACKEND/README.md)
- [🌐 Web Interface Guide](FRONTEND/README.md)
- [📱 iOS App Guide](MOBILE/README.md)

## 🙏 Acknowledgments

- **Google & DeepMind** for Gemma 3n and the opportunity to build for impact
- **Ollama team** for making local AI accessible
- **Families worldwide** who inspired this solution

---

**Built with ❤️ by [Malek Gharsallah](https://github.com/GharsallahDev) for the Google Gemma 3n Impact Challenge**
