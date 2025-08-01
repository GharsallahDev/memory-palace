// src/utils/ApiUtils.ts - API Communication Utilities
import type { Memory } from "../types/MemoryTypes";

const apiConfig = {
  baseUrl: "http://localhost:3000",
  authToken: "",
  isInitialized: false,
};

async function initializeApi() {
  if (apiConfig.isInitialized) return;
  try {
    const response = await fetch(`${apiConfig.baseUrl}/api/config`);
    if (!response.ok)
      throw new Error(`Failed to fetch API config: ${response.statusText}`);
    const config = await response.json();
    apiConfig.baseUrl = `http://${config.serverIP}:${config.port}`;
    apiConfig.authToken = config.authToken;
    apiConfig.isInitialized = true;
  } catch (error) {
    console.error("❌ CRITICAL: Could not initialize API service.", error);
    throw error;
  }
}

async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> {
  if (!apiConfig.isInitialized) await initializeApi();
  try {
    const response = await fetch(`${apiConfig.baseUrl}${endpoint}`, {
      ...options,
      headers: {
        "Content-Type": "application/json",
        "x-auth-token": apiConfig.authToken,
        ...options.headers,
      },
    });
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(
        errorData.detail ||
          errorData.error ||
          `Request failed with status ${response.status}`
      );
    }
    const contentType = response.headers.get("content-type");
    if (contentType && contentType.indexOf("application/json") !== -1) {
      return await response.json();
    }
    return (await response.text()) as T;
  } catch (error) {
    console.error(`API Error (${endpoint}):`, error);
    throw error;
  }
}

async function apiRequestFormData<T>(
  endpoint: string,
  formData: FormData,
  options: RequestInit = {}
): Promise<T> {
  if (!apiConfig.isInitialized) await initializeApi();
  try {
    const response = await fetch(`${apiConfig.baseUrl}${endpoint}`, {
      method: "POST",
      ...options,
      headers: {
        "x-auth-token": apiConfig.authToken,
        ...options.headers,
      },
      body: formData,
    });
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(
        errorData.detail ||
          errorData.error ||
          `Request failed with status ${response.status}`
      );
    }
    return await response.json();
  } catch (error) {
    console.error(`API FormData Error (${endpoint}):`, error);
    throw error;
  }
}

interface MemoryApiResponse {
  success: boolean;
  memories: any[];
}
interface SingleMemoryApiResponse {
  success: boolean;
  memory: any;
}
interface PatientProfileResponse {
  success: boolean;
  profile: PatientProfile;
}
interface PatientProfile {
  id?: number | null;
  name: string;
  photoUrl?: string | null;
  description: string;
  birthDate?: string | null;
}

export const MemoryApi = {
  async getAllMemories(): Promise<Memory[]> {
    const data = await apiRequest<MemoryApiResponse>("/api/memories");
    return data.memories.map(convertToMemoryType);
  },

  async getMemoryById(id: string): Promise<Memory | null> {
    try {
      const data = await apiRequest<SingleMemoryApiResponse>(
        `/api/memories/${id}`
      );
      return data.memory ? convertToMemoryType(data.memory) : null;
    } catch (error) {
      console.error(`Failed to fetch memory with ID ${id}:`, error);
      return null;
    }
  },

  async searchMemories(query: string): Promise<Memory[]> {
    const data = await apiRequest<MemoryApiResponse>(
      `/api/memories/search?q=${encodeURIComponent(query)}`
    );
    return data.memories.map(convertToMemoryType);
  },

  async uploadPhotoMemory(
    file: File,
    metadata: { title?: string; description?: string }
  ): Promise<Memory | null> {
    const formData = new FormData();
    formData.append("photo", file);
    formData.append("title", metadata.title || "Uploaded Photo");
    formData.append("description", metadata.description || "");
    formData.append("deviceName", "Memory Palace Web");
    const data = await apiRequestFormData<{ memory: any }>(
      "/api/memories/photo",
      formData
    );
    return data.memory ? convertToMemoryType(data.memory) : null;
  },

  async getMemoryStats(): Promise<any> {
    return await apiRequest<any>("/api/memories/stats");
  },

  async chat(query: string): Promise<any> {
    return await apiRequest<any>("/api/memories/chat", {
      method: "POST",
      body: JSON.stringify({ query }),
    });
  },

  async voiceChat(audioFile: File): Promise<any> {
    const formData = new FormData();
    formData.append("voice", audioFile);
    return await apiRequestFormData<any>("/api/memories/voice-chat", formData);
  },

  async chatWithPhoto(photoFile: File, query: string): Promise<any> {
    const formData = new FormData();
    formData.append("photo", photoFile);
    formData.append("query", query);
    return await apiRequestFormData<any>(
      "/api/memories/chat-with-photo",
      formData
    );
  },

  async textToSpeech(text: string): Promise<string> {
    if (!apiConfig.isInitialized) await initializeApi();
    try {
      const response = await fetch(`${apiConfig.baseUrl}/api/tts`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-auth-token": apiConfig.authToken,
        },
        body: JSON.stringify({ text }),
      });
      if (!response.ok) {
        throw new Error(`TTS request failed with status ${response.status}`);
      }
      const blob = await response.blob();
      return URL.createObjectURL(blob);
    } catch (error) {
      console.error("API TTS Error:", error);
      throw error;
    }
  },
};

export const PatientApi = {
  async getPatientProfile(): Promise<PatientProfile | null> {
    try {
      const data = await apiRequest<PatientProfileResponse>(
        "/api/patient/profile"
      );
      return data.profile;
    } catch (e) {
      return null;
    }
  },
  async savePatientProfile(
    profileData: Partial<PatientProfile>,
    photoFile?: File
  ): Promise<PatientProfile | null> {
    const formData = new FormData();
    if (profileData.name) formData.append("name", profileData.name);
    if (profileData.description)
      formData.append("description", profileData.description);
    if (profileData.birthDate)
      formData.append("birthDate", profileData.birthDate);
    if (photoFile) formData.append("photo", photoFile);
    const data = await apiRequestFormData<PatientProfileResponse>(
      "/api/patient/profile",
      formData
    );
    return data.profile;
  },
};

function convertToMemoryType(apiMemory: any): Memory {
  return {
    id: apiMemory.id?.toString() || "",
    type: apiMemory.type || "photo",
    title: apiMemory.title || "Untitled",
    description: apiMemory.description || "",
    content:
      apiMemory.imageUrl ||
      apiMemory.videoUrl ||
      apiMemory.audioUrl ||
      apiMemory.content ||
      "",
    date:
      apiMemory.whenWasThis ||
      (apiMemory.timestamp
        ? new Date(apiMemory.timestamp).toLocaleDateString()
        : "Unknown Date"),
    location: apiMemory.whereWasThis || "",
    people: apiMemory.whoWasThere
      ? apiMemory.whoWasThere
          .split(",")
          .map((p: string) => p.trim())
          .filter(Boolean)
      : [],
    tags: [],
    recordedBy: apiMemory.deviceName || "Unknown",
  };
}
export { initializeApi };