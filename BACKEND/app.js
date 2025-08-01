// File: app.js
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const http = require('http');

require('dotenv').config();

const databaseService = require('./src/services/DatabaseService');
const PersonService = require('./src/services/PersonService');
const MemoryService = require('./src/services/MemoryService');
const FileService = require('./src/services/FileService');
const PatientService = require('./src/services/PatientService');
const ProactiveTriggerService = require('./src/services/ProactiveTriggerService');
const WebSocketService = require('./src/services/WebSocketService');

const memoriesRoutes = require('./src/routes/memories');
const peopleRoutes = require('./src/routes/people');
const authRoutes = require('./src/routes/auth');
const patientRoutes = require('./src/routes/patient');
const ttsRoutes = require('./src/routes/tts');
const proactiveRoutes = require('./src/routes/proactive');

const { getLocalIP } = require('./src/utils/helpers');
const { checkAuth } = require('./src/middleware/authMiddleware');

const app = express();
const httpServer = http.createServer(app);
const PORT = process.env.PORT || 3000;
const AUTH_TOKEN = process.env.AUTH_TOKEN;

if (!AUTH_TOKEN) {
  console.error('❌ FATAL ERROR: AUTH_TOKEN is not defined in the .env file.');
  process.exit(1);
}

fs.mkdirSync('./tts-cache', { recursive: true });

const personService = new PersonService();
const fileService = new FileService();
const memoryService = new MemoryService(personService, fileService);
const patientService = new PatientService();
const proactiveTriggerService = new ProactiveTriggerService(memoryService);
const webSocketService = new WebSocketService();

webSocketService.initialize(httpServer);

app.locals.databaseService = databaseService;
app.locals.personService = personService;
app.locals.memoryService = memoryService;
app.locals.fileService = fileService;
app.locals.patientService = patientService;
app.locals.proactiveTriggerService = proactiveTriggerService;
app.locals.webSocketService = webSocketService;
app.locals.AUTH_TOKEN = AUTH_TOKEN;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static('public'));
app.use('/uploads', express.static('uploads'));
app.use('/tts-cache', express.static('tts-cache'));

// Request logging for monitoring
app.use((req, res, next) => {
  console.log(`[ACCESS] ${req.method} ${req.path} - from ${req.ip}`);
  next();
});

// Public routes
app.get('/api/config', (req, res) => {
  res.json({
    serverIP: getLocalIP(),
    port: PORT,
    authToken: AUTH_TOKEN,
  });
});

app.get('/health', (req, res) => {
  const wsStats = webSocketService.getStats();
  res.json({
    status: 'Hub running!',
    websocket: {
      connected_clients: wsStats.totalConnections,
      patient_clients: wsStats.patientClients,
      queued_memories: wsStats.queuedMemories,
    },
  });
});

app.get('/api/memories/stats', (req, res) => {
  try {
    const memoryStats = app.locals.memoryService.getStatistics();
    const personStats = app.locals.personService.getStats();
    res.json({
      total: memoryStats.totalMemories,
      photos: memoryStats.photoCount,
      voices: memoryStats.voiceCount,
      videos: memoryStats.videoCount,
      texts: memoryStats.textCount,
      people: personStats.totalPeople,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Protected routes
app.use('/api/memories', checkAuth, memoriesRoutes);
app.use('/api/people', checkAuth, peopleRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/patient', checkAuth, patientRoutes);
app.use('/api/tts', checkAuth, ttsRoutes);
app.use('/api/proactive', checkAuth, proactiveRoutes);

// 404 handler for API routes
app.use('/api/*', (req, res) => {
  res.status(404).json({ success: false, error: 'API endpoint not found' });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('❌ Unhandled error:', err);
  res.status(500).json({ success: false, error: 'Internal server error', message: err.message });
});

// Start HTTP server
httpServer.listen(PORT, '0.0.0.0', () => {
  const localIP = getLocalIP();
  console.log('');
  console.log('🚀 Memory Palace Hub Started!');
  console.log(`📍 Hub URL: http://${localIP}:${PORT}`);
  console.log(`🔑 Auth Token: ${AUTH_TOKEN.substring(0, 12)}...`);
  console.log(`🌐 Web Interface: http://${localIP}:${PORT}`);
  console.log(`🔌 WebSocket Server: Ready for real-time connections`);
  console.log('');

  webSocketService.cleanupOldQueuedMemories();
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('📴 Shutting down Memory Palace Hub...');
  if (webSocketService.io) {
    webSocketService.io.close();
  }
  databaseService.close();
  httpServer.close(() => {
    console.log('✅ Server shutdown complete');
    process.exit(0);
  });
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});