# Backend Hub - Memory Palace Family Coordination Center

**Node.js server managing the complete family memory ecosystem with real-time intelligence**

## 🎯 Overview

The Backend Hub serves as the central coordination point for the Memory Palace family ecosystem. Built with Node.js and Express, it manages memory storage, family member coordination, real-time communication, and background AI processing.

## 🏗️ Architecture

### Core Components

- **Express REST API**: Family memory management and coordination
- **WebSocket Server**: Real-time proactive memory delivery
- **Background Workers**: AI processing and trigger generation
- **SQLite Database**: Local memory and people storage
- **File Management**: Secure multimedia storage and serving

### Service Architecture

```
┌─────────────────────────────────────────┐
│            Node.js Hub                  │
├─────────────────────────────────────────┤
│  Express API    │  WebSocket Server     │
│  • REST Routes  │  • Real-time Push     │
│  • Auth & CORS  │  • Proactive Triggers │
│  • File Serving │  • Family Coordination│
├─────────────────────────────────────────┤
│  Background Workers                     │
│  • AI Caption Generation                │
│  • Proactive Trigger Detection          │
│  • Avatar Generation                    │
│  • Memory Analysis Pipeline             │
├─────────────────────────────────────────┤
│  Data Layer                             │
│  • SQLite Database                      │
│  • File Storage Management              │
│  • Vector Embeddings                    │
└─────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

```bash
# Node.js 18+
node --version

# npm 9+
npm --version
```

### Installation

```bash
cd BACKEND/
npm install
```

### Configuration

```bash
# Copy environment template
cp .env.example .env

# Generate secure auth token
openssl rand -hex 32

# Edit configuration
nano .env
```

Required environment variables:

```env
# Server Configuration
PORT=3000
AUTH_TOKEN=your_secure_token_here

# AI Service Integration
PYTHON_SERVICE_URL=http://127.0.0.1:5000

# Database
DATABASE_PATH=./data/memory_palace.db

# File Storage
UPLOADS_DIR=./uploads
MAX_FILE_SIZE=100MB
```

### Database Setup

```bash
# Create data directories
mkdir -p data uploads/avatars

# Database auto-initializes on first run
npm start
```

### Running the Service

```bash
# Development mode with auto-reload
npm run dev

# Production mode
npm start

# Background worker only
npm run worker

# Both main app and worker
npm start & npm run worker
```

## 📋 API Endpoints

### Memory Management

#### Upload Photo Memory

```http
POST /api/memories/photo
Content-Type: multipart/form-data
x-auth-token: your_auth_token

file: photo.jpg
title: "Family Beach Day"
description: "Amazing day at the coast"
whenWasThis: "2024-07-15"
whereWasThis: "Santa Monica Beach"
peopleIds: ["1", "2", "3"]
faceTags: [{"id": "uuid", "personId": 1, "boundingBox": {...}}]
```

#### Upload Voice Memory

```http
POST /api/memories/voice
Content-Type: multipart/form-data
x-auth-token: your_auth_token

file: story.m4a
title: "Grandpa's War Stories"
context: "Stories from WWII service"
duration: 180.5
peopleIds: ["1"]
```

#### Upload Video Memory

```http
POST /api/memories/video
Content-Type: multipart/form-data
x-auth-token: your_auth_token

file: video.mp4
title: "Birthday Celebration"
description: "85th birthday party"
whenWasThis: "2024-03-20"
peopleIds: ["1", "2", "3", "4"]
```

#### Create Text Memory

```http
POST /api/memories/text
Content-Type: application/json
x-auth-token: your_auth_token

{
  "title": "Family Recipe",
  "content": "Grandma's secret chocolate chip cookie recipe...",
  "description": "Passed down through generations",
  "peopleIds": ["1", "5"]
}
```

#### Get All Memories

```http
GET /api/memories
x-auth-token: your_auth_token
```

#### Get Memory by ID

```http
GET /api/memories/123
x-auth-token: your_auth_token
```

### Chat Integration

#### Text Chat

```http
POST /api/memories/chat
Content-Type: application/json
x-auth-token: your_auth_token

{
  "query": "Tell me about happy family moments"
}
```

#### Voice Chat

```http
POST /api/memories/voice-chat
Content-Type: multipart/form-data
x-auth-token: your_auth_token

file: voice_query.webm
```

#### Photo Chat

```http
POST /api/memories/chat-with-photo
Content-Type: multipart/form-data
x-auth-token: your_auth_token

file: photo.jpg
```

### People Management

#### Get All People

```http
GET /api/people
x-auth-token: your_auth_token
```

#### Add Person

```http
POST /api/people
Content-Type: application/json
x-auth-token: your_auth_token

{
  "name": "Sarah Johnson",
  "relationship": "Daughter",
  "deviceName": "Sarah's iPhone"
}
```

#### Update Person

```http
PUT /api/people/123
Content-Type: application/json
x-auth-token: your_auth_token

{
  "name": "Sarah Johnson-Smith",
  "relationship": "Daughter"
}
```

### Patient Profile

#### Get Patient Profile

```http
GET /api/patient/profile
x-auth-token: your_auth_token
```

#### Update Patient Profile

```http
POST /api/patient/profile
Content-Type: multipart/form-data
x-auth-token: your_auth_token

file: profile_photo.jpg
name: "Robert Johnson"
description: "Loving grandfather and retired teacher"
birthDate: "1946-03-15"
```

### Proactive System

#### Check Proactive Triggers

```http
GET /api/proactive/check
x-auth-token: your_auth_token
```

#### Get Proactive History

```http
GET /api/proactive/history
x-auth-token: your_auth_token
```

#### Mark Proactive Memory as Viewed

```http
POST /api/proactive/view/123
x-auth-token: your_auth_token
```

## 🔧 Service Architecture

### Manager Pattern

The backend uses a clean manager-based architecture:

```javascript
// Service initialization
const personService = new PersonService();
const fileService = new FileService();
const memoryService = new MemoryService(personService, fileService);
const proactiveTriggerService = new ProactiveTriggerService(memoryService);
const webSocketService = new WebSocketService();
```

#### MemoryService

Handles all memory-related operations:

```javascript
class MemoryService {
  async createPhotoMemory(memoryData, imageFile, faceTags, peopleIds, perceptualHash) {
    // 1. Store memory in database
    // 2. Process face tags and people associations
    // 3. Generate vector embeddings
    // 4. Queue background AI processing
    // 5. Perform proactive analysis
  }
}
```

#### PersonService

Manages people and relationships:

```javascript
class PersonService {
  async getAllPeople() {
    // Returns enriched people list including patient profile
    // Generates avatar URLs for display
  }
}
```

#### ProactiveTriggerService

Intelligent memory surfacing:

```javascript
class ProactiveTriggerService {
  async checkAllTriggers() {
    // 1. Check "On This Day" memories
    // 2. Detect anniversaries
    // 3. Find seasonal memories
    // 4. Build cinematic experiences
    // 5. Return best trigger for delivery
  }
}
```

#### WebSocketService

Real-time family coordination:

```javascript
class WebSocketService {
  sendProactiveMemory(trigger, clientType = 'patient') {
    // Delivers proactive memories in real-time
    // Queues for offline clients
    // Tracks engagement analytics
  }
}
```

### Background Workers

#### Main Worker Loop (`worker.js`)

Runs every 5 minutes:

```javascript
// AI caption generation
await handleCaptionJob(job);

// Avatar processing
await processAvatarQueue();

// Proactive trigger detection
await checkAndSendProactiveMemories();

// Cleanup old records
cleanupOldProactiveMemories();
```

#### AI Caption Processing

```javascript
async function handleCaptionJob(job) {
  // 1. Load image file
  // 2. Send to AI service for captioning
  // 3. Store generated caption
  // 4. Update memory with enriched description
}
```

#### Avatar Generation

```javascript
async function processAvatarQueue() {
  // 1. Find people needing avatars
  // 2. Extract faces from their photos using bounding boxes
  // 3. Crop and resize to 200x200 avatar
  // 4. Update person record with avatar path
}
```

## 🗄️ Database Schema

### Core Tables

#### memories

```sql
CREATE TABLE memories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL CHECK (type IN ('photo', 'voice', 'video', 'text')),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  content TEXT DEFAULT '',
  who_was_there TEXT DEFAULT '',
  when_was_this TEXT DEFAULT '',
  where_was_this TEXT DEFAULT '',
  context TEXT DEFAULT '',
  duration REAL DEFAULT NULL,
  timestamp TEXT NOT NULL,
  device_name TEXT NOT NULL,
  image_file TEXT DEFAULT NULL,
  audio_file TEXT DEFAULT NULL,
  video_file TEXT DEFAULT NULL,
  thumbnail_file TEXT DEFAULT NULL,
  generated_caption TEXT DEFAULT NULL,
  transcription_text TEXT DEFAULT NULL,
  perceptual_hash TEXT DEFAULT NULL,
  embedding BLOB DEFAULT NULL,
  anniversary_type TEXT DEFAULT NULL,
  seasonal_tags TEXT DEFAULT NULL,
  proactive_score REAL DEFAULT 0
);
```

#### people

```sql
CREATE TABLE people (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  relationship TEXT,
  created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  last_seen_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  device_name TEXT DEFAULT 'Unknown Device',
  avatar_file TEXT DEFAULT NULL,
  avatar_source_memory_id INTEGER DEFAULT NULL
);
```

#### face_tags

```sql
CREATE TABLE face_tags (
  id TEXT PRIMARY KEY,
  memory_id INTEGER NOT NULL,
  person_id INTEGER DEFAULT NULL,
  confidence REAL NOT NULL,
  bounding_box TEXT NOT NULL,
  detected_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  is_manual BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE,
  FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE SET NULL
);
```

#### proactive_memories

```sql
CREATE TABLE proactive_memories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  trigger_type TEXT NOT NULL,
  trigger_date DATE NOT NULL,
  memory_ids TEXT NOT NULL,
  delivered_at DATETIME DEFAULT NULL,
  viewed_at DATETIME DEFAULT NULL,
  dismissed_at DATETIME DEFAULT NULL,
  created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
```

## 🌐 WebSocket Real-Time System

### Client Authentication

```javascript
// Client connects and authenticates
socket.emit('authenticate', {
  authToken: 'your_auth_token',
  clientType: 'patient', // or 'caregiver'
});
```

### Proactive Memory Delivery

```javascript
// Server sends proactive memory
socket.emit('proactive_memory', {
  id: 'proactive_123',
  trigger_type: 'anniversary',
  title: 'Your Wedding Day - 45 Years Ago',
  description: 'A special day to remember',
  memory_count: 3,
  memories: [...],
  director_response: { /* Full cinematic experience */ }
});
```

### Client Response Tracking

```javascript
// Client responds to proactive memory
socket.emit('proactive_response', {
  proactiveId: 'proactive_123',
  response: 'viewed', // or 'dismissed'
});
```

## 🔒 Security Features

### Authentication

- Token-based authentication for all API endpoints
- Rate limiting to prevent abuse
- CORS configuration for cross-origin requests

### File Security

- Input validation and sanitization
- File type restrictions
- Size limits to prevent DoS
- Secure file serving with proper headers

### Data Protection

- SQL injection prevention with prepared statements
- Input validation on all endpoints
- Error message sanitization
- No sensitive data in logs

## 📊 Performance Optimizations

### Database

- SQLite with WAL mode for better concurrency
- Prepared statements for repeated queries
- Foreign key constraints for data integrity
- Indices on frequently queried columns

### File Handling

- Efficient multipart upload processing
- Streaming for large file transfers
- Background processing for AI tasks
- Automatic cleanup of temporary files

### Memory Management

- Connection pooling for database
- Proper resource cleanup
- Memory-efficient file processing
- Background garbage collection

## 🔧 Configuration Options

### Environment Variables

```env
# Core Settings
PORT=3000
NODE_ENV=production
AUTH_TOKEN=secure_random_token

# AI Integration
PYTHON_SERVICE_URL=http://127.0.0.1:5000
AI_SERVICE_TIMEOUT=30000

# File Storage
UPLOADS_DIR=./uploads
MAX_FILE_SIZE=100MB
ALLOWED_IMAGE_TYPES=jpg,jpeg,png,gif,bmp,webp
ALLOWED_AUDIO_TYPES=mp3,wav,m4a,aac,ogg,webm

# Database
DATABASE_PATH=./data/memory_palace.db
ENABLE_WAL_MODE=true

# WebSocket
WEBSOCKET_PING_INTERVAL=25000
WEBSOCKET_PING_TIMEOUT=5000
```

## 🧪 Testing

### Health Check

```bash
curl http://localhost:3000/health
```

### API Testing

```bash
# Test connection
curl -H "x-auth-token: your_token" http://localhost:3000/api/memories

# Upload test photo
curl -X POST \
  -H "x-auth-token: your_token" \
  -F "photo=@test.jpg" \
  -F "title=Test Memory" \
  http://localhost:3000/api/memories/photo
```

### WebSocket Testing

```javascript
const io = require('socket.io-client');
const socket = io('http://localhost:3000');

socket.emit('authenticate', {
  authToken: 'your_token',
  clientType: 'patient',
});

socket.on('proactive_memory', data => {
  console.log('Received proactive memory:', data);
});
```

## 🐛 Troubleshooting

### Common Issues

**Database Locked**

```bash
# Check for running processes
ps aux | grep node

# Kill zombie processes
pkill -f "node.*app.js"

# Restart with clean database connection
npm start
```

**File Upload Errors**

- Check disk space: `df -h`
- Verify upload directory permissions: `ls -la uploads/`
- Check file size limits in configuration

**WebSocket Connection Issues**

- Verify firewall settings allow port 3000
- Check CORS configuration
- Ensure authentication token is valid
