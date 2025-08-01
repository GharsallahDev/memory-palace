// src/components/ChatInput.tsx
import React, { useState, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Send, Paperclip, Camera, Upload, X, Mic } from "lucide-react";
import "./ChatInput.css";

interface ChatInputProps {
  onSendMessage: (message: string, image?: File) => void;
  onSendVoiceMessage: (audioFile: File) => void;
  disabled?: boolean;
}

interface MediaModalProps {
  isOpen: boolean;
  onClose: () => void;
  onImageSelect: (file: File) => void;
}

interface VoiceModalProps {
  isOpen: boolean;
  onClose: () => void;
  onVoiceMessage: (audioFile: File) => void;
}

const MediaModal: React.FC<MediaModalProps> = ({
  isOpen,
  onClose,
  onImageSelect,
}) => {
  const [showCameraFeed, setShowCameraFeed] = useState(false);
  const [stream, setStream] = useState<MediaStream | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const startCamera = async () => {
    try {
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: "user",
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
        audio: false,
      });
      setStream(mediaStream);
      setShowCameraFeed(true);

      setTimeout(() => {
        if (videoRef.current) {
          videoRef.current.srcObject = mediaStream;
          videoRef.current.play().catch(console.error);
        }
      }, 100);
    } catch (error) {
      alert(
        `Camera access failed: ${
          error instanceof Error ? error.message : String(error)
        }`
      );
      fileInputRef.current?.click();
    }
  };

  const capturePhoto = () => {
    if (videoRef.current && canvasRef.current) {
      const video = videoRef.current;
      const canvas = canvasRef.current;
      const ctx = canvas.getContext("2d");

      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      ctx?.drawImage(video, 0, 0);

      canvas.toBlob(
        (blob) => {
          if (blob) {
            const file = new File([blob], "camera-capture.jpg", {
              type: "image/jpeg",
            });
            onImageSelect(file);
            closeCamera();
            onClose();
          }
        },
        "image/jpeg",
        0.8
      );
    }
  };

  const closeCamera = () => {
    if (stream) {
      stream.getTracks().forEach((track) => track.stop());
    }
    setStream(null);
    setShowCameraFeed(false);
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      onImageSelect(file);
      onClose();
    }
  };

  const handleClose = () => {
    closeCamera();
    onClose();
  };

  if (!isOpen) return null;

  return (
    <motion.div
      className="media-modal-overlay"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      onClick={handleClose}
    >
      <motion.div
        className="media-modal"
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.8, opacity: 0 }}
        onClick={(e) => e.stopPropagation()}
      >
        {showCameraFeed ? (
          <div className="camera-feed-container">
            <div className="camera-header">
              <h3>Take a Photo</h3>
              <button className="close-camera-btn" onClick={closeCamera}>
                <X size={20} />
              </button>
            </div>
            <div className="camera-viewport">
              <video
                ref={videoRef}
                autoPlay
                playsInline
                muted
                className="camera-video"
              />
              <canvas ref={canvasRef} style={{ display: "none" }} />
            </div>
            <div className="camera-controls">
              <button className="capture-btn" onClick={capturePhoto}>
                <div className="capture-circle" />
              </button>
            </div>
          </div>
        ) : (
          <div className="media-options">
            <div className="modal-header">
              <h3>Add Media</h3>
              <button className="close-btn" onClick={handleClose}>
                <X size={20} />
              </button>
            </div>
            <div className="options-grid">
              <motion.button
                className="option-card camera-option"
                onClick={startCamera}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                <div className="option-icon">
                  <Camera size={32} />
                </div>
                <div className="option-text">
                  <h4>Take Photo</h4>
                  <p>Capture with camera</p>
                </div>
              </motion.button>
              <motion.button
                className="option-card upload-option"
                onClick={() => fileInputRef.current?.click()}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                <div className="option-icon">
                  <Upload size={32} />
                </div>
                <div className="option-text">
                  <h4>Upload File</h4>
                  <p>Choose from device</p>
                </div>
              </motion.button>
            </div>
          </div>
        )}
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleFileSelect}
          style={{ display: "none" }}
        />
      </motion.div>
    </motion.div>
  );
};

const VoiceModal: React.FC<VoiceModalProps> = ({
  isOpen,
  onClose,
  onVoiceMessage,
}) => {
  const [isRecording, setIsRecording] = useState(false);
  const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(
    null
  );
  const recordedChunksRef = useRef<Blob[]>([]);

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      recordedChunksRef.current = [];
      let mimeType = "audio/webm";
      if (MediaRecorder.isTypeSupported("audio/webm;codecs=opus")) {
        mimeType = "audio/webm;codecs=opus";
      } else if (MediaRecorder.isTypeSupported("audio/mp4")) {
        mimeType = "audio/mp4";
      }

      const recorder = new MediaRecorder(stream, { mimeType });

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) recordedChunksRef.current.push(event.data);
      };

      recorder.onstop = () => {
        if (recordedChunksRef.current.length === 0) return;
        const audioBlob = new Blob(recordedChunksRef.current, {
          type: mimeType,
        });
        if (audioBlob.size === 0) return;
        const extension = mimeType.includes("mp4") ? "m4a" : "webm";
        const audioFile = new File([audioBlob], `voice-message.${extension}`, {
          type: mimeType,
        });
        onVoiceMessage(audioFile);
        onClose();
      };

      recorder.onerror = (event) =>
        console.error("MediaRecorder error:", event);
      setMediaRecorder(recorder);
      recorder.start(250);
      setIsRecording(true);
    } catch (error) {
      console.error("Microphone access failed:", error);
    }
  };

  const stopRecording = () => {
    if (mediaRecorder && isRecording) {
      mediaRecorder.stop();
      mediaRecorder.stream.getTracks().forEach((track) => track.stop());
      setIsRecording(false);
      setMediaRecorder(null);
    }
  };

  const handleToggleRecording = () => {
    if (isRecording) stopRecording();
    else startRecording();
  };

  const handleClose = () => {
    if (isRecording) stopRecording();
    onClose();
  };

  if (!isOpen) return null;

  return (
    <motion.div
      className="voice-modal-overlay"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      onClick={handleClose}
    >
      <motion.div
        className="voice-card"
        initial={{ scale: 0.8, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        exit={{ scale: 0.8, opacity: 0 }}
        onClick={(e) => e.stopPropagation()}
      >
        <input
          className="voice-input"
          hidden
          type="checkbox"
          checked={isRecording}
          onChange={handleToggleRecording}
          id="voice-command"
        />
        <div className="voice-inner-card">
          <div className="voice-trigger-wrap">
            <label className="voice-trigger" htmlFor="voice-command" />
            <svg
              viewBox="0 0 24 24"
              className="voice-mic"
              strokeLinejoin="round"
              strokeLinecap="round"
              strokeWidth="2.5"
              stroke="currentColor"
              fill="none"
            >
              <path d="m19.5,10.89c0,4.44-3.36,8.04-7.5,8.04s-7.5-3.6-7.5-8.04" />
              <line x1="12" y1="22.42" x2="12" y2="18.93" />
              <rect
                x="8.38"
                y="1.81"
                width="7.23"
                height="13.25"
                rx="3.62"
                ry="3.62"
              />
            </svg>
            <div className="voice-spectrum">
              {[...Array(45)].map((_, i) => (
                <b key={i} style={{ "--index": i } as React.CSSProperties} />
              ))}
            </div>
          </div>
          <div className="voice-content">
            <div className="voice-title">Voice Chat</div>
            <div className="voice-description">
              {isRecording ? "Listening..." : "Tap microphone to talk"}
            </div>
          </div>
        </div>
      </motion.div>
    </motion.div>
  );
};

const ChatInput: React.FC<ChatInputProps> = ({
  onSendMessage,
  onSendVoiceMessage,
  disabled = false,
}) => {
  const [message, setMessage] = useState("");
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [isDragging, setIsDragging] = useState(false);
  const [showMediaModal, setShowMediaModal] = useState(false);
  const [showVoiceModal, setShowVoiceModal] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleSubmit = useCallback(() => {
    if (disabled || (!message.trim() && !selectedImage)) return;
    onSendMessage(message.trim(), selectedImage || undefined);
    setMessage("");
    setSelectedImage(null);
    setPreviewUrl(null);
    if (textareaRef.current) {
      textareaRef.current.style.height = "auto";
    }
  }, [message, selectedImage, disabled, onSendMessage]);

  const handleVoiceMessage = useCallback(
    (audioFile: File) => {
      onSendVoiceMessage(audioFile);
    },
    [onSendVoiceMessage]
  );

  const handleImageSelect = useCallback((file: File) => {
    if (file && file.type.startsWith("image/")) {
      setSelectedImage(file);
      const url = URL.createObjectURL(file);
      setPreviewUrl(url);
    }
  }, []);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  }, []);

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setIsDragging(false);
      const file = e.dataTransfer.files[0];
      if (file) handleImageSelect(file);
    },
    [handleImageSelect]
  );

  const removeImage = useCallback(() => {
    setSelectedImage(null);
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
      setPreviewUrl(null);
    }
  }, [previewUrl]);

  const handleTextareaChange = useCallback(
    (e: React.ChangeEvent<HTMLTextAreaElement>) => {
      setMessage(e.target.value);
      const textarea = e.target;
      textarea.style.height = "auto";
      textarea.style.height = `${Math.min(textarea.scrollHeight, 120)}px`;
    },
    []
  );

  const handleKeyPress = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        handleSubmit();
      }
    },
    [handleSubmit]
  );

  return (
    <>
      <motion.div
        className="chat-input-container"
        initial={{ y: 100, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ delay: 0.3, duration: 0.6 }}
      >
        <AnimatePresence>
          {previewUrl && (
            <motion.div
              className="image-preview-container"
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.3 }}
            >
              <div className="image-preview">
                <img src={previewUrl} alt="Preview" className="preview-image" />
                <motion.button
                  className="remove-image-btn"
                  onClick={removeImage}
                  whileHover={{ scale: 1.1 }}
                  whileTap={{ scale: 0.9 }}
                >
                  <X size={14} />
                </motion.button>
              </div>
              <div className="preview-label">
                <Camera size={16} />
                Photo ready to share
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        <div className="chat-form-container">
          <div className="input-background-fill"></div>
          <div
            className={`input-wrapper ${isDragging ? "dragging" : ""}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
          >
            <AnimatePresence>
              {isDragging && (
                <motion.div
                  className="drag-overlay"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                >
                  <div className="drag-content">
                    <Upload size={48} />
                    <div className="drag-text">Drop your photo here</div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
            <motion.button
              type="button"
              className="media-btn"
              onClick={() => setShowMediaModal(true)}
              disabled={disabled}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              title="Add media"
            >
              <Paperclip size={20} />
            </motion.button>
            <motion.button
              type="button"
              className="voice-btn"
              onClick={() => setShowVoiceModal(true)}
              disabled={disabled}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              title="Voice chat"
            >
              <Mic size={20} />
            </motion.button>
            <div className="text-input-container">
              <textarea
                ref={textareaRef}
                value={message}
                onChange={handleTextareaChange}
                onKeyPress={handleKeyPress}
                placeholder={
                  selectedImage
                    ? "Ask about your photo..."
                    : "What would you like to remember?"
                }
                disabled={disabled}
                className="message-input"
                rows={1}
              />
            </div>
            <motion.button
              type="button"
              className="send-btn"
              onClick={handleSubmit}
              disabled={disabled || (!message.trim() && !selectedImage)}
              whileHover={{ scale: disabled ? 1 : 1.05 }}
              whileTap={{ scale: disabled ? 1 : 0.95 }}
              title="Send message"
            >
              {disabled ? (
                <div className="loading-spinner" />
              ) : (
                <Send size={20} />
              )}
            </motion.button>
          </div>
        </div>
      </motion.div>

      <AnimatePresence>
        {showMediaModal && (
          <MediaModal
            isOpen={showMediaModal}
            onClose={() => setShowMediaModal(false)}
            onImageSelect={handleImageSelect}
          />
        )}
      </AnimatePresence>
      <AnimatePresence>
        {showVoiceModal && (
          <VoiceModal
            isOpen={showVoiceModal}
            onClose={() => setShowVoiceModal(false)}
            onVoiceMessage={handleVoiceMessage}
          />
        )}
      </AnimatePresence>
    </>
  );
};

export default ChatInput;