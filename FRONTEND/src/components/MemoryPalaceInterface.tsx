// src/components/MemoryPalaceInterface.tsx
import React, { useState, useRef, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import CinematicMemoryDisplay from "./CinematicMemoryDisplay";
import ContextualTriggers from "./ContextualTriggers";
import ChatInput from "./ChatInput";
import PatientSettings from "./PatientSettings";
import SharedHeader from "./SharedHeader";
import AudioPlayer from "./AudioPlayer";
import type { Memory } from "../types/MemoryTypes";
import { MemoryApi, PatientApi, initializeApi } from "../utils/ApiUtils";
import webSocketService, {
  type ProactiveMemory,
} from "../services/WebSocketService";
import ProactiveMemoryNotification from "./ProactiveMemoryNotification";
import "./MemoryPalaceInterface.css";

// Type definitions for AI and server responses
interface DirectorResponse {
  response_type: "narrative" | "cinematic_show";
  message?: string;
  show_title?: string;
  scenes?: EnrichedScene[];
}

interface EnrichedScene {
  memory: {
    id: string;
    type: string;
    title: string;
    contentUrl: string;
  };
  narration: string;
  narrationAudioUrl?: string;
}

interface Message {
  id: string;
  type: "user" | "ai";
  content: string;
  timestamp: Date;
  image?: string;
  audioUrl?: string;
  isVoiceMessage?: boolean;
  memories: Memory[];
  directorResponse?: DirectorResponse | null;
}

interface MemoryPalaceInterfaceProps {
  onBack: () => void;
}

let globalApiConfig: { baseUrl: string; authToken: string } | null = null;

const MemoryPalaceInterface: React.FC<MemoryPalaceInterfaceProps> = ({
  onBack,
}) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [showTriggers, setShowTriggers] = useState(true);
  const [showSettings, setShowSettings] = useState(false);
  const [patientContext, setPatientContext] = useState<any>(null);
  const [error, setError] = useState<string | null>(null);
  const [proactiveMemory, setProactiveMemory] =
    useState<ProactiveMemory | null>(null);
  const chatEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const init = async () => {
      try {
        await initializeApi();
        await fetchInitialData();

        const response = await fetch("http://localhost:3000/api/config");
        const config = await response.json();
        globalApiConfig = {
          baseUrl: `http://${config.serverIP}:${config.port}`,
          authToken: config.authToken,
        };

        webSocketService.initialize(
          globalApiConfig.baseUrl,
          globalApiConfig.authToken,
          {
            onProactiveMemory: (memory) => {
              setProactiveMemory(memory);
            },
          }
        );
      } catch (err) {
        handleApiError(err, "Initialization Failed");
      }
    };
    init();

    return () => {
      webSocketService.disconnect();
    };
  }, []);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleApiError = (err: unknown, context: string) => {
    const errorMessage =
      err instanceof Error ? err.message : "An unknown error occurred.";
    setError(
      `${context}: ${errorMessage}. Please ensure the backend and AI services are running.`
    );
    console.error(`[${context}]`, err);
  };

  const fetchInitialData = async () => {
    try {
      setError(null);
      const context = await PatientApi.getPatientProfile();
      setPatientContext(context);
    } catch (err) {
      handleApiError(err, "Failed to load initial data");
    }
  };

  const processAndDisplayResponse = (directorResponse: DirectorResponse) => {
    const aiMessage: Message = {
      id: (Date.now() + 1).toString(),
      type: "ai",
      content:
        directorResponse.response_type === "narrative"
          ? directorResponse.message || ""
          : directorResponse.show_title || "",
      timestamp: new Date(),
      memories: [],
      directorResponse: directorResponse,
    };
    setMessages((prev) => [...prev, aiMessage]);
  };

  const handleUserMessage = async (
    content: string,
    image?: File,
    triggerTitle?: string
  ) => {
    setIsProcessing(true);
    setShowTriggers(false);
    setError(null);

    const userMessage: Message = {
      id: Date.now().toString(),
      type: "user",
      content: triggerTitle || content,
      timestamp: new Date(),
      image: image ? URL.createObjectURL(image) : undefined,
      memories: [],
    };
    setMessages((prev) => [...prev, userMessage]);

    try {
      let directorResponse: DirectorResponse;
      if (image) {
        directorResponse = await MemoryApi.chatWithPhoto(image, content);
      } else {
        directorResponse = await MemoryApi.chat(content);
      }
      processAndDisplayResponse(directorResponse);
    } catch (err) {
      handleApiError(err, "AI Chat Failed");
      const errorResponse: Message = {
        id: "error-" + Date.now(),
        type: "ai",
        content: "I'm sorry, I'm having a little trouble right now.",
        timestamp: new Date(),
        memories: [],
      };
      setMessages((prev) => [...prev, errorResponse]);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleVoiceMessage = async (audioFile: File) => {
    setIsProcessing(true);
    setShowTriggers(false);
    setError(null);

    const audioUrl = URL.createObjectURL(audioFile);
    const userVoiceMessage: Message = {
      id: Date.now().toString(),
      type: "user",
      content: "🎤 Voice message",
      timestamp: new Date(),
      memories: [],
      audioUrl: audioUrl,
      isVoiceMessage: true,
    };
    setMessages((prev) => [...prev, userVoiceMessage]);

    try {
      const directorResponse = await MemoryApi.voiceChat(audioFile);
      processAndDisplayResponse(directorResponse);
    } catch (err) {
      handleApiError(err, "AI Voice Chat Failed");
      const errorResponse: Message = {
        id: "error-" + Date.now(),
        type: "ai",
        content: "I'm sorry, I had trouble understanding your voice message.",
        timestamp: new Date(),
        memories: [],
      };
      setMessages((prev) => [...prev, errorResponse]);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleProactiveView = async (proactiveId: string) => {
    if (globalApiConfig) {
      try {
        await fetch(
          `${globalApiConfig.baseUrl}/api/proactive/view/${proactiveId}`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-auth-token": globalApiConfig.authToken,
            },
          }
        );
      } catch (error) {
        console.error(`❌ Error tracking proactive view:`, error);
      }
    }
    webSocketService.respondToProactiveMemory(proactiveId, "viewed");

    setProactiveMemory(null);
    setShowTriggers(false);
    setError(null);

    if (proactiveMemory?.director_response) {
      processAndDisplayResponse(proactiveMemory.director_response);
    } else {
      handleApiError(
        new Error("Proactive memory did not contain a pre-built experience."),
        "Proactive View Failed"
      );
    }
  };

  const handleProactiveDismiss = async (proactiveId: string) => {
    if (globalApiConfig) {
      try {
        await fetch(
          `${globalApiConfig.baseUrl}/api/proactive/dismiss/${proactiveId}`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-auth-token": globalApiConfig.authToken,
            },
          }
        );
      } catch (error) {
        console.error(`❌ Error tracking proactive dismissal:`, error);
      }
    }
    webSocketService.respondToProactiveMemory(proactiveId, "dismissed");
    setProactiveMemory(null);

    const dismissMessage: Message = {
      id: "proactive-dismissed-" + Date.now(),
      type: "ai",
      content:
        "No problem! Those special memories will be here whenever you're ready.",
      timestamp: new Date(),
      memories: [],
    };
    setMessages((prev) => [...prev, dismissMessage]);
  };

  const handleTriggerClick = (query: string, title: string) => {
    handleUserMessage(query, undefined, title);
  };

  const getPartnerName = (): string | null => {
    // TODO: Replace with data from patientContext state once available.
    // This allows the "My Love" button to be personalized.
    // Example: return patientContext?.partnerName || null;
    return "Mary";
  };

  const headerActions = [
    {
      icon: "user" as const,
      onClick: () => setShowSettings(true),
      title: "Patient Profile",
    },
  ];

  return (
    <motion.div
      className="memory-palace-interface"
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{ duration: 0.8 }}
    >
      <SharedHeader
        onBack={onBack}
        patientName={patientContext?.name}
        actions={headerActions}
        isProcessing={isProcessing}
      />

      <AnimatePresence>
        {error && (
          <motion.div
            className="error-banner"
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -20 }}
          >
            <div className="error-content">
              <span className="error-icon">⚠️</span>
              {error}
              <button className="error-close" onClick={() => setError(null)}>
                ×
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <div className="palace-content">
        <div className="chat-container">
          <AnimatePresence>
            {messages.map((message) => (
              <motion.div
                key={message.id}
                className={`message ${message.type}`}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5 }}
              >
                {message.type === "user" ? (
                  <div className="user-message">
                    {message.image && (
                      <div className="uploaded-image">
                        <img src={message.image} alt="Uploaded memory" />
                      </div>
                    )}
                    {message.isVoiceMessage && message.audioUrl ? (
                      <AudioPlayer audioUrl={message.audioUrl} />
                    ) : (
                      <div className="user-text">{message.content}</div>
                    )}
                  </div>
                ) : (
                  <div className="ai-message">
                    <CinematicMemoryDisplay
                      directorResponse={message.directorResponse}
                    />
                  </div>
                )}
              </motion.div>
            ))}
          </AnimatePresence>
          {isProcessing && (
            <motion.div className="processing-indicator">
              <div className="processing-content">
                <div className="processing-spinner">
                  <div className="spinner-inner"></div>
                </div>
                <span className="processing-text">Remembering...</span>
              </div>
            </motion.div>
          )}
          <div ref={chatEndRef} />
        </div>
        <AnimatePresence>
          {showTriggers && !error && (
            <ContextualTriggers
              onTrigger={handleTriggerClick}
              getPartnerName={getPartnerName}
            />
          )}
        </AnimatePresence>
      </div>
      <ChatInput
        onSendMessage={handleUserMessage}
        onSendVoiceMessage={handleVoiceMessage}
        disabled={isProcessing}
      />
      <PatientSettings
        isOpen={showSettings}
        onClose={() => setShowSettings(false)}
      />
      <ProactiveMemoryNotification
        proactiveMemory={proactiveMemory}
        onView={handleProactiveView}
        onDismiss={handleProactiveDismiss}
        onClose={() => setProactiveMemory(null)}
      />
    </motion.div>
  );
};

export default MemoryPalaceInterface;