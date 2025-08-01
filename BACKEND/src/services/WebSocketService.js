// src/services/WebSocketService.js
const { Server } = require('socket.io');

class WebSocketService {
  constructor() {
    this.io = null;
    this.connectedClients = new Map();
    this.proactiveQueue = new Map();
  }

  /**
   * Initialize Socket.IO with HTTP server
   * @param {Object} httpServer - Express HTTP server
   */
  initialize(httpServer) {
    this.io = new Server(httpServer, {
      cors: {
        origin: '*',
        methods: ['GET', 'POST'],
        credentials: true,
      },
      transports: ['websocket', 'polling'],
    });

    this.setupEventHandlers();
    console.log('✅ WebSocket service initialized');
  }

  setupEventHandlers() {
    this.io.on('connection', (socket) => {
      socket.on('authenticate', (data) => {
        const { authToken, clientType = 'patient' } = data;

        this.connectedClients.set(socket.id, {
          socket: socket,
          authToken: authToken,
          clientType: clientType,
          connectedAt: new Date(),
          lastSeen: new Date(),
        });

        socket.emit('authenticated', {
          clientId: socket.id,
          status: 'connected',
          message: 'Successfully connected to Memory Palace',
        });

        this.sendQueuedProactiveMemories(socket.id);
      });

      socket.on('ping', () => {
        socket.emit('pong');
        this.updateLastSeen(socket.id);
      });

      socket.on('proactive_response', (data) => {
        // TODO: save user interaction with proactive memory
      });

      socket.on('disconnect', (reason) => {
        this.connectedClients.delete(socket.id);
      });

      socket.on('error', (error) => {
        console.error(`❌ Socket error for ${socket.id}:`, error);
      });
    });
  }

  /**
   * Send a proactive memory to connected clients
   * @param {Object} proactiveMemory - The proactive memory trigger
   * @param {string} targetClientType - 'patient', 'caregiver', or 'all'
   */
  sendProactiveMemory(proactiveMemory, targetClientType = 'patient') {
    const targetClients = this.getTargetClients(targetClientType);

    if (targetClients.length === 0) {
      this.queueProactiveMemory(proactiveMemory, targetClientType);
      return false;
    }

    const payload = {
      id: `proactive_${Date.now()}`,
      trigger_type: proactiveMemory.trigger_type,
      title: proactiveMemory.title,
      description: proactiveMemory.description,
      memory_count: proactiveMemory.memories.length,
      created_at: new Date().toISOString(),
      memories: proactiveMemory.memories.map((memory) => ({
        id: memory.id,
        type: memory.type,
        title: memory.title,
        description: memory.description,
      })),
      director_response: proactiveMemory.director_response || null,
    };

    let deliveredCount = 0;
    targetClients.forEach((clientInfo) => {
      try {
        clientInfo.socket.emit('proactive_memory', payload);
        deliveredCount++;
      } catch (error) {
        console.error(
          `❌ Failed to send proactive memory to ${clientInfo.socket.id}:`,
          error.message
        );
      }
    });

    return deliveredCount > 0;
  }

  /**
   * Queue proactive memory for clients that aren't connected
   * @param {Object} proactiveMemory
   * @param {string} targetClientType
   */
  queueProactiveMemory(proactiveMemory, targetClientType) {
    const queueKey = `${targetClientType}_queue`;

    if (!this.proactiveQueue.has(queueKey)) {
      this.proactiveQueue.set(queueKey, []);
    }

    this.proactiveQueue.get(queueKey).push({
      ...proactiveMemory,
      queuedAt: new Date().toISOString(),
      director_response: proactiveMemory.director_response || null,
    });
  }

  /**
   * Send queued proactive memories to a newly connected client
   * @param {string} clientId
   */
  sendQueuedProactiveMemories(clientId) {
    const clientInfo = this.connectedClients.get(clientId);
    if (!clientInfo) return;

    const queueKey = `${clientInfo.clientType}_queue`;
    const queuedMemories = this.proactiveQueue.get(queueKey) || [];

    if (queuedMemories.length === 0) return;

    queuedMemories.forEach((memory) => {
      const payload = {
        id: `proactive_queued_${Date.now()}`,
        trigger_type: memory.trigger_type,
        title: memory.title,
        description: memory.description,
        memory_count: memory.memories.length,
        created_at: memory.queuedAt,
        is_queued: true,
        memories: memory.memories.map((mem) => ({
          id: mem.id,
          type: mem.type,
          title: mem.title,
          description: mem.description,
        })),
        director_response: memory.director_response || null,
      };

      clientInfo.socket.emit('proactive_memory', payload);
    });

    // Clear the queue after sending
    this.proactiveQueue.set(queueKey, []);
  }

  /**
   * Get connected clients by type
   * @param {string} clientType
   * @returns {Array}
   */
  getTargetClients(clientType) {
    const clients = Array.from(this.connectedClients.values());

    if (clientType === 'all') {
      return clients;
    }

    return clients.filter((client) => client.clientType === clientType);
  }

  updateLastSeen(clientId) {
    const clientInfo = this.connectedClients.get(clientId);
    if (clientInfo) {
      clientInfo.lastSeen = new Date();
    }
  }

  getStats() {
    const clients = Array.from(this.connectedClients.values());

    return {
      totalConnections: clients.length,
      patientClients: clients.filter((c) => c.clientType === 'patient').length,
      caregiverClients: clients.filter((c) => c.clientType === 'caregiver').length,
      queuedMemories: Array.from(this.proactiveQueue.values()).reduce(
        (sum, queue) => sum + queue.length,
        0
      ),
      connections: clients.map((c) => ({
        id: c.socket.id,
        type: c.clientType,
        connectedAt: c.connectedAt,
        lastSeen: c.lastSeen,
      })),
    };
  }

  /**
   * Cleanup old queued memories (older than 24 hours)
   */
  cleanupOldQueuedMemories() {
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    for (const [queueKey, memories] of this.proactiveQueue.entries()) {
      const filteredMemories = memories.filter((memory) => {
        const queuedAt = new Date(memory.queuedAt);
        return queuedAt > oneDayAgo;
      });

      if (filteredMemories.length !== memories.length) {
        this.proactiveQueue.set(queueKey, filteredMemories);
      }
    }
  }
}

module.exports = WebSocketService;