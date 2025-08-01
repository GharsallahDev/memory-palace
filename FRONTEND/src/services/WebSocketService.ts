// src/services/WebSocketService.ts
import { io, Socket } from "socket.io-client";

export interface ProactiveMemory {
  id: string;
  trigger_type: "on_this_day" | "anniversary" | "seasonal";
  title: string;
  description: string;
  memory_count: number;
  created_at: string;
  is_queued?: boolean;
  memories: Array<{
    id: string;
    type: string;
    title: string;
    description: string;
  }>;
  director_response?: {
    response_type: "narrative" | "cinematic_show";
    message?: string;
    show_title?: string;
    scenes?: Array<{
      memory_id: string;
      narration: string;
      narrationAudioUrl?: string;
      narrationDurationMs?: number;
      memory: {
        id: string;
        type: string;
        title: string;
        contentUrl: string;
      };
    }>;
  } | null;
}

export interface WebSocketServiceCallbacks {
  onProactiveMemory?: (memory: ProactiveMemory) => void;
  onConnectionChange?: (connected: boolean) => void;
  onNotification?: (notification: {
    id: string;
    type: string;
    message: string;
    timestamp: string;
  }) => void;
}

class WebSocketService {
  private socket: Socket | null = null;
  private callbacks: WebSocketServiceCallbacks = {};
  private authToken: string = "";
  private baseUrl: string = "http://localhost:3000";
  private isConnecting: boolean = false;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;

  /**
   * Initialize WebSocket connection
   */
  async initialize(
    baseUrl: string,
    authToken: string,
    callbacks: WebSocketServiceCallbacks = {}
  ) {
    this.baseUrl = baseUrl;
    this.authToken = authToken;
    this.callbacks = callbacks;

    if (this.socket?.connected || this.isConnecting) {
      return;
    }

    this.isConnecting = true;

    try {
      this.socket = io(baseUrl, {
        transports: ["websocket", "polling"],
        timeout: 10000,
        retries: 3,
        forceNew: true,
      });
      this.setupEventListeners();
    } catch (error) {
      console.error("❌ Failed to initialize WebSocket:", error);
      this.isConnecting = false;
      this.callbacks.onConnectionChange?.(false);
    }
  }

  /**
   * Setup Socket.IO event listeners
   */
  private setupEventListeners() {
    if (!this.socket) return;

    this.socket.on("connect", () => {
      this.isConnecting = false;
      this.reconnectAttempts = 0;
      this.socket?.emit("authenticate", {
        authToken: this.authToken,
        clientType: "patient",
      });
      this.callbacks.onConnectionChange?.(true);
    });

    this.socket.on("disconnect", (reason) => {
      this.isConnecting = false;
      this.callbacks.onConnectionChange?.(false);
      if (reason !== "io server disconnect") {
        this.handleReconnection();
      }
    });

    this.socket.on("connect_error", (error) => {
      console.error("❌ WebSocket connection error:", error);
      this.isConnecting = false;
      this.callbacks.onConnectionChange?.(false);
      this.handleReconnection();
    });

    this.socket.on("authenticated", (data) => {
      console.log("WebSocket authenticated:", data);
    });

    this.socket.on("proactive_memory", (data: ProactiveMemory) => {
      this.callbacks.onProactiveMemory?.(data);
    });

    this.socket.on("notification", (data) => {
      this.callbacks.onNotification?.(data);
    });
  }

  private handleReconnection() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.log("❌ Max reconnection attempts reached");
      return;
    }

    const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
    this.reconnectAttempts++;

    setTimeout(() => {
      if (!this.socket?.connected && !this.isConnecting) {
        this.socket?.connect();
      }
    }, delay);
  }

  /**
   * Send proactive memory response
   */
  respondToProactiveMemory(
    proactiveId: string,
    response: "viewed" | "dismissed" | "saved"
  ) {
    if (!this.socket?.connected) {
      console.warn("⚠️ Cannot send response - WebSocket not connected");
      return;
    }
    this.socket.emit("proactive_response", { proactiveId, response });
  }

  /**
   * Disconnect WebSocket
   */
  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
    this.isConnecting = false;
    this.reconnectAttempts = 0;
    this.callbacks.onConnectionChange?.(false);
  }
}

const webSocketService = new WebSocketService();
export default webSocketService;