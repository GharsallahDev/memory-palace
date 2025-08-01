// src/types/MemoryTypes.ts

export interface Memory {
  id: string;
  type: "photo" | "video" | "audio" | "text";
  title: string;
  description: string;
  content: string;
  date: string;
  location?: string;
  people: string[];
  tags: string[];
  recordedBy?: string;
  emotion?: "happy" | "nostalgic" | "loving" | "peaceful" | "excited";
  metadata?: {
    duration?: number;
    width?: number;
    height?: number;
    fileSize?: number;
  };
}

export interface Message {
  id: string;
  type: "user" | "ai";
  content: string;
  timestamp: Date;
  image?: string;
  audioUrl?: string;
  isVoiceMessage?: boolean;
  memories: Memory[];
  directorResponse?: any;
}

export type TriggerType =
  | "date-based"
  | "weather-based"
  | "time-based"
  | "seasonal";

export interface PhotoRecognitionResult {
  memories: Memory[];
  response: string;
  confidence: number;
  recognizedPeople: string[];
  location?: string;
  date?: string;
}

export interface MemorySearchResult {
  memories: Memory[];
  relevanceScore: number;
  searchTerms: string[];
}