# Frontend Web Interface - Memory Palace Patient Experience

**React + TypeScript application providing cinematic memory experiences for elderly users**

## 🎯 Overview

The Frontend Web Interface is the patient-facing component of Memory Palace, designed specifically for elderly users experiencing memory challenges. Built with React 19 and TypeScript, it provides a gentle, accessible interface for exploring memories through AI-powered conversations and cinematic experiences.

## ✨ Key Features

- **🎭 Cinematic Memory Experiences**: Full-screen movie-like presentations with synchronized narration
- **💬 Multi-Modal Chat**: Text, voice, and photo conversation with Gemma 3n
- **⚡ Real-Time Proactive Notifications**: Anniversary and seasonal memory triggers via WebSocket
- **🎨 Elderly-Focused Design**: Large text, high contrast, simplified navigation
- **🎵 Audio-First Interface**: Professional TTS and voice interaction capabilities
- **🔒 Privacy-First**: All processing through local family hub, no external services

## 🏗️ Architecture

### Technology Stack

- **React 19**: Latest React with concurrent features
- **TypeScript**: Full type safety and developer experience
- **Framer Motion**: Smooth animations and page transitions
- **Socket.IO Client**: Real-time WebSocket communication
- **Three.js**: 3D visual effects and enhanced experiences
- **Tone.js**: Advanced audio synthesis and processing

### Component Architecture

```
src/
├── components/
│   ├── WelcomeScreen.tsx           # Cinematic entrance
│   ├── Dashboard.tsx               # Family hub interface
│   ├── MemoryPalaceInterface.tsx   # Main patient chat
│   ├── CinematicMemoryDisplay.tsx  # Full-screen experiences
│   ├── ProactiveMemoryNotification.tsx # Real-time triggers
│   ├── ChatInput.tsx               # Multi-modal input
│   ├── ContextualTriggers.tsx      # Conversation starters
│   ├── PatientSettings.tsx         # Profile management
│   ├── AudioPlayer.tsx             # Voice playback
│   └── SharedHeader.tsx            # Navigation header
├── services/
│   └── WebSocketService.ts         # Real-time communication
├── utils/
│   └── ApiUtils.ts                 # Backend integration
└── types/
    └── MemoryTypes.ts              # TypeScript definitions
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
cd FRONTEND/
npm install
```

### Configuration

The frontend auto-discovers the backend hub via the `/api/config` endpoint. No manual configuration required.

### Development

```bash
# Development server with hot reload
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Type checking
npm run lint
```

### Access Points

- **Development**: http://localhost:5173
- **Patient Interface**: Click "Enter Your Palace"
- **Family Dashboard**: Click "Family Hub"

## 🎭 Core Components

### WelcomeScreen - Cinematic Entrance

```typescript
// 5-second particle animation with neon title effect
const WelcomeScreen: React.FC<WelcomeScreenProps> = ({
  onEnter,
  onEnterDashboard
}) => {
  // Particle system with 40+ animated elements
  // "City nights" neon text animation
  // Two entry points: Patient vs Family Dashboard
}
```

### MemoryPalaceInterface - Main Patient Experience

```typescript
const MemoryPalaceInterface: React.FC = ({ onBack }) => {
  // Multi-modal chat system
  // WebSocket proactive memory integration
  // Patient context awareness
  // Real-time AI processing states
}
```

**Core Capabilities:**

- **Text Chat**: Natural conversation with Gemma 3n
- **Voice Chat**: Speech-to-text → AI response → Text-to-speech
- **Photo Chat**: Upload photo → Face recognition → Memory discovery
- **Proactive Triggers**: Real-time anniversary/seasonal notifications

### CinematicMemoryDisplay - The Crown Jewel

```typescript
interface DirectorResponse {
  response_type: 'narrative' | 'cinematic_show'
  message?: string
  show_title?: string
  scenes?: EnrichedScene[]
}

const CinematicMemoryDisplay: React.FC = ({ directorResponse }) => {
  // Full-screen portal-based cinema mode
  // Multi-phase video playback (subtitle → video → transition)
  // Synchronized audio narration with progress tracking
  // Scene management and auto-progression
}
```

**Cinematic Features:**

- **Full-Screen Immersion**: Portal-based rendering outside normal DOM
- **Multi-Phase Playback**: Subtitle overlays → pure video → seamless transitions
- **Audio Synchronization**: Narration progress tracking with scene timing
- **Professional Transitions**: Scale, blur, opacity animations between scenes
- **Memory Type Adaptation**: Different rendering for photos/videos/audio

### ProactiveMemoryNotification - Intelligent Triggers

```typescript
interface ProactiveMemory {
  id: string
  trigger_type: 'on_this_day' | 'anniversary' | 'seasonal'
  title: string
  description: string
  memory_count: number
  memories: Memory[]
  director_response?: DirectorResponse
}

const ProactiveMemoryNotification: React.FC = ({
  proactiveMemory,
  onView,
  onDismiss
}) => {
  // Real-time trigger notifications
  // Emotional call-to-action buttons
  // Memory preview cards
  // "Prepared while you were away" messaging
}
```

### ChatInput - Multi-Modal Input System

```typescript
const ChatInput: React.FC = ({
  onSendMessage,
  onSendVoiceMessage,
  disabled
}) => {
  // Text input with auto-resize
  // Camera capture with live preview
  // Voice recording with spectrum visualization
  // Drag & drop photo support
  // Image preview with metadata
}
```

**Input Modalities:**

- **Text**: Auto-resizing textarea with smart placeholders
- **Voice**: Real-time spectrum visualization during recording
- **Camera**: Live camera feed with capture controls
- **File Upload**: Drag & drop with preview generation
- **Hybrid**: Photo + text query combinations

## 🌐 Real-Time Communication

### WebSocket Integration

```typescript
class WebSocketService {
  initialize(
    baseUrl: string,
    authToken: string,
    callbacks: WebSocketServiceCallbacks
  ) {
    // Auto-reconnection with exponential backoff
    // Token-based authentication
    // Client type identification (patient vs caregiver)
    // Proactive memory delivery
  }

  respondToProactiveMemory(
    proactiveId: string,
    response: 'viewed' | 'dismissed'
  ) {
    // User engagement tracking
    // Analytics for family insights
  }
}
```

**Real-Time Features:**

- **Proactive Memory Delivery**: Anniversary/seasonal triggers pushed instantly
- **Offline Queuing**: Memories stored when user disconnected
- **Engagement Analytics**: Viewed/dismissed tracking for family dashboard
- **Auto-Reconnection**: Network resilience with smart retry logic

### API Integration

```typescript
export const MemoryApi = {
  async chat(query: string): Promise<DirectorResponse> {
    // Text-based memory conversation
  },

  async voiceChat(audioFile: File): Promise<DirectorResponse> {
    // Voice-to-text → AI response → Rich media response
  },

  async chatWithPhoto(
    photoFile: File,
    query: string
  ): Promise<DirectorResponse> {
    // Photo recognition → Related memory discovery → AI response
  },

  async textToSpeech(text: string): Promise<string> {
    // On-demand speech synthesis for any AI response
  }
}
```

## 🎨 Design Philosophy

### Elderly-Centered UX

- **Large Touch Targets**: Minimum 44px for easy tapping
- **High Contrast**: WCAG AAA compliance for visual accessibility
- **Simple Navigation**: Minimal cognitive load, clear visual hierarchy
- **Error Recovery**: Gentle error messages with retry options
- **Loading States**: Clear feedback during AI processing

### Emotional Design

- **Warm Color Palette**: Soft, comforting colors throughout
- **Personal Language**: "Tell me about..." rather than technical terms
- **Contextual Triggers**: "Happy Times", "My Love", "The Children"
- **Gentle Animations**: Smooth, non-jarring transitions
- **Voice-First**: Prominent microphone controls

### Cinematic Quality

- **Movie-Like Presentations**: Full-screen immersive experiences
- **Professional Transitions**: Fade, scale, blur effects between scenes
- **Synchronized Audio**: Perfect timing between narration and visuals
- **Scene Progression**: Intelligent pacing for optimal emotional impact

## 🔧 Advanced Features

### Contextual Triggers

```typescript
const triggers = [
  {
    query: 'Tell me a story about a very happy time.',
    title: 'Happy Times',
    subtitle: 'A joyful memory',
    icon: Smile,
    color: 'rgba(76, 175, 80, 0.2)'
  },
  {
    query: partnerName
      ? `Tell me a special story about me and ${partnerName}.`
      : 'Tell me a story about love and partnership.',
    title: 'My Love',
    subtitle: 'Our story together',
    icon: Heart,
    color: 'rgba(233, 30, 99, 0.2)'
  }
  // Dynamically personalized based on family context
]
```

### Voice Interface

```typescript
// Professional voice recording with spectrum visualization
const VoiceModal: React.FC = ({ onVoiceMessage }) => {
  // MediaRecorder with cross-browser compatibility
  // Real-time 45-bar spectrum analyzer
  // Format optimization (WebM, MP4 fallbacks)
  // Professional microphone UI with animated feedback
}
```

### Camera Integration

```typescript
// Live camera feed with professional controls
const MediaModal: React.FC = ({ onImageSelect }) => {
  // getUserMedia with error handling
  // Live video preview with capture controls
  // File upload fallback for camera failures
  // Image optimization and preview generation
}
```

## 📱 Responsive Design

### Breakpoint Strategy

```css
/* Mobile-first responsive design */
@media (min-width: 768px) {
  /* Tablet */
}
@media (min-width: 1024px) {
  /* Desktop */
}
@media (min-width: 1440px) {
  /* Large screens */
}

/* Elderly-specific optimizations */
@media (min-width: 1024px) {
  .chat-input {
    font-size: 1.25rem; /* Larger text */
  }
  .trigger-card {
    min-height: 120px; /* Bigger touch targets */
  }
}
```

### Accessibility Features

- **Keyboard Navigation**: Full keyboard accessibility
- **Screen Reader Support**: Proper ARIA labels and roles
- **Focus Management**: Clear focus indicators and logical tab order
- **Color Independence**: Information not conveyed by color alone
- **Motion Preferences**: Respects `prefers-reduced-motion`

## 🎵 Audio System

### AudioPlayer Component

```typescript
const AudioPlayer: React.FC<{ audioUrl: string }> = ({ audioUrl }) => {
  // Web Audio API for accurate duration detection
  // 20-bar animated waveform visualization
  // Click-to-seek functionality
  // Real-time progress indicators
  // Format compatibility across browsers
}
```

**Audio Features:**

- **Waveform Visualization**: 20-bar animated spectrum
- **Accurate Duration**: Web Audio API fallback for HTML5 limitations
- **Interactive Seeking**: Click anywhere on waveform to jump
- **Professional Controls**: Play/pause with smooth animations

### Text-to-Speech Integration

```typescript
// On-demand speech synthesis for any text
const handlePlayNarrative = async (text: string) => {
  const audioUrl = await MemoryApi.textToSpeech(text)
  const audio = new Audio(audioUrl)
  audio.play()
}
```

## 🚨 Error Handling

### Graceful Degradation

```typescript
// Network resilience
const handleApiError = (err: unknown, context: string) => {
  const errorMessage = err instanceof Error ? err.message : 'Unknown error'
  setError(`${context}: ${errorMessage}. Please ensure services are running.`)

  // Graceful fallback responses
  const fallbackResponse: Message = {
    type: 'ai',
    content: "I'm sorry, I'm having a little trouble right now.",
    timestamp: new Date(),
    memories: []
  }
  setMessages(prev => [...prev, fallbackResponse])
}
```

### User-Friendly Messaging

- **No Technical Jargon**: "Having trouble connecting" vs "WebSocket error"
- **Actionable Guidance**: "Please check your connection" with retry button
- **Graceful Fallbacks**: Offline mode for core functionality
- **Recovery Options**: Clear paths to resolve issues

## 🔒 Privacy & Security

### Local-First Architecture

- **No External APIs**: All communication through family hub only
- **Client-Side Processing**: Image/audio processing before upload
- **Secure WebSocket**: Token-based authentication for real-time features
- **Memory Protection**: No sensitive data in browser storage

### Data Handling

```typescript
// No localStorage/sessionStorage usage (Claude.ai restrictions)
// All state managed through React hooks
const [messages, setMessages] = useState<Message[]>([])
const [patientContext, setPatientContext] = useState<PatientProfile | null>(
  null
)

// Secure file handling
const handleImageSelect = useCallback((file: File) => {
  if (file && file.type.startsWith('image/')) {
    setSelectedImage(file)
    const url = URL.createObjectURL(file) // Memory-based, not persisted
    setPreviewUrl(url)
  }
}, [])
```

## 🧪 Testing & Quality

### Development Tools

```bash
# Type checking
npm run lint

# Component testing
npm run test

# Build verification
npm run build && npm run preview
```

### Performance Optimization

- **Code Splitting**: Lazy loading for cinematic components
- **Asset Optimization**: Image compression and format selection
- **Bundle Analysis**: Webpack bundle analyzer for size optimization
- **Memory Management**: Proper cleanup of audio/video resources

## 🎯 User Journey

### First-Time Experience

1. **Cinematic Welcome**: 5-second particle animation entrance
2. **Choice Presentation**: "Enter Your Palace" vs "Family Hub"
3. **Patient Interface**: Contextual conversation triggers
4. **First Interaction**: Voice, text, or photo conversation
5. **AI Response**: Narrative or cinematic experience
6. **Proactive Discovery**: Real-time memory notifications

### Ongoing Experience

1. **Gentle Re-entry**: Familiar interface with new memory triggers
2. **Contextual Conversations**: AI adapts to user preferences and history
3. **Proactive Surprises**: Anniversary and seasonal memory deliveries
4. **Family Growth**: New memories appear as family members contribute
5. **Emotional Connection**: Strengthened bonds through shared experiences

## 🐛 Troubleshooting

### Common Issues

**Backend Connection Failed**

```typescript
// Check backend hub status
curl http://localhost:3000/health

// Verify network connectivity
ping your-hub-ip-address

// Check authentication
curl -H "x-auth-token: your_token" http://localhost:3000/api/config
```

**WebSocket Connection Issues**

- Verify hub is running on correct port
- Check firewall settings allow WebSocket connections
- Ensure authentication token is valid and current

**Media Upload Problems**

- Check file size limits (100MB default)
- Verify supported formats (jpg, png, mp4, m4a, webm)
- Ensure sufficient disk space on hub device

**Audio Playback Issues**

- Verify browser audio permissions
- Check TTS service availability on hub
- Test with different audio formats

### Browser Compatibility

- **Chrome/Edge**: Full feature support including WebSocket
- **Safari**: iOS optimizations for voice recording
- **Firefox**: Full compatibility with media capture
- **Mobile Browsers**: Touch-optimized interface with responsive design

---
