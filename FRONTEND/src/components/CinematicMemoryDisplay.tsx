// src/components/CinematicMemoryDisplay.tsx
import React, { useState, useEffect, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { createPortal } from "react-dom";
import { X, RotateCcw, Film, Loader, Volume2, Pause } from "lucide-react";
import type { DirectorResponse, EnrichedScene } from "./MemoryPalaceInterface";
import AudioPlayer from "./AudioPlayer";
import { MemoryApi } from "../utils/ApiUtils";
import "./CinematicMemoryDisplay.css";

interface CinematicMemoryDisplayProps {
  directorResponse: DirectorResponse | undefined;
}

const CinematicMemoryDisplay: React.FC<CinematicMemoryDisplayProps> = ({
  directorResponse,
}) => {
  const [currentSceneIndex, setCurrentSceneIndex] = useState(0);
  const [cinemaState, setCinemaState] = useState<
    "not_started" | "playing" | "finished"
  >("not_started");
  const [videoPhase, setVideoPhase] = useState<
    "subtitle" | "playing" | "finished"
  >("subtitle");
  const [narrativeAudioState, setNarrativeAudioState] = useState<
    "idle" | "loading" | "playing"
  >("idle");
  const [narrationProgress, setNarrationProgress] = useState(0);
  const videoRef = useRef<HTMLVideoElement>(null);
  const narrativeAudioRef = useRef<HTMLAudioElement | null>(null);
  const sceneAudioRef = useRef<HTMLAudioElement | null>(null);

  const isCinematic = directorResponse?.response_type === "cinematic_show";
  const scenes: EnrichedScene[] = isCinematic ? directorResponse.scenes : [];
  const currentScene = scenes[currentSceneIndex];

  const nextScene = useCallback(() => {
    if (currentSceneIndex < scenes.length - 1) {
      setCurrentSceneIndex((prev) => prev + 1);
      setVideoPhase("subtitle");
    } else {
      setCinemaState("finished");
    }
  }, [currentSceneIndex, scenes.length]);

  useEffect(() => {
    setNarrationProgress(0);
  }, [currentSceneIndex]);

  useEffect(() => {
    if (isCinematic && cinemaState === "not_started") {
      setCinemaState("playing");
    }
  }, [isCinematic, cinemaState]);

  useEffect(() => {
    if (cinemaState !== "playing" || !currentScene) return;

    const { memory, narrationAudioUrl } = currentScene;
    const memoryType = memory.type;

    if (narrationAudioUrl) {
      const narrationAudio = new Audio(narrationAudioUrl);
      const handleTimeUpdate = () => {
        if (narrationAudio.duration) {
          setNarrationProgress(
            (narrationAudio.currentTime / narrationAudio.duration) * 100
          );
        }
      };
      const handleCanPlay = () => narrationAudio.play().catch(console.error);
      const handleEnded = () => {
        setNarrationProgress(100);
        if (memoryType === "video") setVideoPhase("playing");
        else nextScene();
      };

      narrationAudio.addEventListener("timeupdate", handleTimeUpdate);
      narrationAudio.addEventListener("canplaythrough", handleCanPlay);
      narrationAudio.addEventListener("ended", handleEnded);

      return () => {
        narrationAudio.pause();
        narrationAudio.removeEventListener("timeupdate", handleTimeUpdate);
        narrationAudio.removeEventListener("canplaythrough", handleCanPlay);
        narrationAudio.removeEventListener("ended", handleEnded);
      };
    } else {
      if (memoryType === "video") setVideoPhase("playing");
      else {
        const timer = setTimeout(nextScene, 5000);
        return () => clearTimeout(timer);
      }
    }
  }, [currentScene, cinemaState, nextScene]);

  useEffect(() => {
    if (currentScene?.memory.type === "video" && videoRef.current) {
      const video = videoRef.current;
      const showFirstFrame = () => video.pause();
      video.currentTime = 0;
      video.addEventListener("loadeddata", showFirstFrame);
      return () => video.removeEventListener("loadeddata", showFirstFrame);
    }
  }, [currentScene]);

  useEffect(() => {
    if (
      currentScene?.memory.type === "video" &&
      videoPhase === "playing" &&
      videoRef.current
    ) {
      videoRef.current.play().catch(console.error);
    }
  }, [videoPhase, currentScene]);

  const handleVideoEnded = () => {
    setVideoPhase("finished");
    setTimeout(nextScene, 500);
  };

  const handleReplay = () => {
    setCurrentSceneIndex(0);
    setVideoPhase("subtitle");
    setCinemaState("playing");
  };

  const handlePlayNarrative = async (text: string) => {
    if (narrativeAudioState === "playing") {
      narrativeAudioRef.current?.pause();
      setNarrativeAudioState("idle");
      return;
    }
    setNarrativeAudioState("loading");
    try {
      const audioUrl = await MemoryApi.textToSpeech(text);
      narrativeAudioRef.current = new Audio(audioUrl);
      narrativeAudioRef.current.play();
      narrativeAudioRef.current.onended = () => setNarrativeAudioState("idle");
      setNarrativeAudioState("playing");
    } catch (error) {
      console.error("Failed to play narrative:", error);
      setNarrativeAudioState("idle");
    }
  };

  if (!isCinematic) {
    const message = directorResponse?.message || "I'm not sure what to say.";
    return (
      <motion.div
        className="text-only-response"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <div className="ai-text">{message}</div>
        <button
          className="play-narrative-btn"
          onClick={() => handlePlayNarrative(message)}
          disabled={narrativeAudioState === "loading"}
        >
          {narrativeAudioState === "loading" && (
            <Loader className="btn-icon spinning" size={18} />
          )}
          {narrativeAudioState === "playing" && (
            <Pause className="btn-icon" size={18} />
          )}
          {narrativeAudioState === "idle" && (
            <Volume2 className="btn-icon" size={18} />
          )}
        </button>
      </motion.div>
    );
  }

  if (cinemaState === "finished") {
    return (
      <motion.div
        className="post-cinema-response"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <div className="ai-text">{directorResponse.show_title}</div>
        <div className="cinema-summary">
          <div className="summary-info">
            <div className="summary-icon">
              <Film size={20} />
            </div>
            <div className="summary-text">
              Presented {scenes.length} memory scene
              {scenes.length > 1 ? "s" : ""}
            </div>
          </div>
          <motion.button
            className="replay-btn"
            onClick={handleReplay}
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
          >
            <RotateCcw size={16} /> Replay
          </motion.button>
        </div>
      </motion.div>
    );
  }

  if (currentScene && currentScene.memory.type === "audio") {
    return <AudioPlayer audioUrl={currentScene.memory.contentUrl || ""} />;
  }

  if (
    cinemaState === "playing" &&
    currentScene &&
    currentScene.memory?.contentUrl
  ) {
    return createPortal(
      <motion.div
        className="cinema-fullscreen"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
      >
        <AnimatePresence>
          {(currentScene.memory.type !== "video" ||
            videoPhase !== "playing") && (
            <motion.div
              className="cinema-header"
              initial={{ y: -100, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: -100, opacity: 0 }}
              transition={{ duration: 0.8 }}
            >
              <div className="cinema-title">{currentScene.memory.title}</div>
              <button
                className="exit-cinema-btn"
                onClick={() => setCinemaState("finished")}
              >
                <X size={20} />
              </button>
            </motion.div>
          )}
        </AnimatePresence>
        <div className="cinema-stage">
          <AnimatePresence mode="wait">
            <motion.div
              key={currentSceneIndex}
              className="cinema-scene"
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 1.2 }}
              transition={{ duration: 1.2, ease: "easeOut" }}
            >
              {currentScene.memory.type === "photo" && (
                <div className="photo-scene">
                  <motion.img
                    src={currentScene.memory.contentUrl}
                    alt={currentScene.memory.title}
                    className="cinema-photo"
                    initial={{ scale: 1.2, filter: "blur(10px)" }}
                    animate={{ scale: 1, filter: "blur(0px)" }}
                    transition={{ duration: 2.5, ease: "easeOut" }}
                  />
                </div>
              )}
              {currentScene.memory.type === "video" && (
                <div className="video-scene">
                  <video
                    ref={videoRef}
                    src={currentScene.memory.contentUrl}
                    className="cinema-video"
                    onEnded={handleVideoEnded}
                    muted={
                      !!currentScene.narrationAudioUrl &&
                      videoPhase !== "playing"
                    }
                    playsInline
                    style={{
                      opacity:
                        videoPhase === "subtitle" || videoPhase === "playing"
                          ? 1
                          : 0,
                    }}
                  />
                  <AnimatePresence>
                    {videoPhase === "subtitle" && (
                      <motion.div
                        className="video-overlay"
                        exit={{ opacity: 0 }}
                      />
                    )}
                  </AnimatePresence>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        </div>
        <AnimatePresence>
          {videoPhase !== "playing" && scenes.length > 1 && (
            <motion.div
              className="cinema-progress-indicator"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 20 }}
              transition={{ duration: 0.5 }}
            >
              {scenes.map((_, index) => (
                <div
                  key={`progress-${index}`}
                  className={`progress-segment ${
                    index === currentSceneIndex ? "active" : ""
                  }`}
                >
                  {index === currentSceneIndex && (
                    <div
                      className="progress-fill"
                      style={{ width: `${narrationProgress}%` }}
                    />
                  )}
                </div>
              ))}
            </motion.div>
          )}
        </AnimatePresence>
        <AnimatePresence>
          {(currentScene.memory.type === "photo" ||
            videoPhase === "subtitle") && (
            <motion.div
              className="cinema-subtitle-center"
              key={`subtitle-${currentSceneIndex}`}
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -30 }}
              transition={{ delay: 0.5, duration: 1 }}
            >
              <div className="subtitle-content">{currentScene.narration}</div>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>,
      document.body
    );
  }

  return null;
};

export default CinematicMemoryDisplay;