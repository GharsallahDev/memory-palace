// src/components/AudioPlayer.tsx
import React, { useState, useRef, useEffect } from "react";
import { motion } from "framer-motion";
import { Play, Pause, Mic2 } from "lucide-react";
import "./AudioPlayer.css";

interface AudioPlayerProps {
  audioUrl: string;
}

const AudioPlayer: React.FC<AudioPlayerProps> = ({ audioUrl }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [duration, setDuration] = useState(0);
  const [currentTime, setCurrentTime] = useState(0);
  const [isLoaded, setIsLoaded] = useState(false);
  const audioRef = useRef<HTMLAudioElement>(null);

  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    const getRealDuration = async () => {
      try {
        const response = await fetch(audioUrl);
        const arrayBuffer = await response.arrayBuffer();
        const audioContext = new (window.AudioContext ||
          (window as any).webkitAudioContext)();
        const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);
        setDuration(audioBuffer.duration);
        setIsLoaded(true);
        audioContext.close();
      } catch (error) {
        console.error("Web Audio API failed to get duration:", error);
        tryHtml5Duration();
      }
    };

    const tryHtml5Duration = () => {
      const checkDuration = () => {
        if (audio.duration && isFinite(audio.duration) && audio.duration > 0) {
          setDuration(audio.duration);
          setIsLoaded(true);
          return true;
        }
        return false;
      };
      if (checkDuration()) return;
      audio.addEventListener("loadedmetadata", checkDuration);
      audio.addEventListener("canplay", checkDuration);
    };

    const handleTimeUpdate = () => setCurrentTime(audio.currentTime);
    const handleEnded = () => {
      setIsPlaying(false);
      setCurrentTime(0);
    };

    audio.addEventListener("timeupdate", handleTimeUpdate);
    audio.addEventListener("ended", handleEnded);
    audio.addEventListener("play", () => setIsPlaying(true));
    audio.addEventListener("pause", () => setIsPlaying(false));

    audio.load();
    getRealDuration();

    return () => {
      audio.removeEventListener("timeupdate", handleTimeUpdate);
      audio.removeEventListener("ended", handleEnded);
      audio.removeEventListener("play", () => setIsPlaying(true));
      audio.removeEventListener("pause", () => setIsPlaying(false));
    };
  }, [audioUrl]);

  const togglePlayPause = () => {
    if (!audioRef.current || !isLoaded) return;
    if (isPlaying) audioRef.current.pause();
    else audioRef.current.play().catch(console.error);
  };

  const handleSeek = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!audioRef.current || !duration || !isLoaded) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const newTime = (clickX / rect.width) * duration;
    audioRef.current.currentTime = newTime;
    setCurrentTime(newTime);
  };

  const formatTime = (timeInSeconds: number) => {
    if (!isFinite(timeInSeconds) || isNaN(timeInSeconds) || timeInSeconds < 0)
      return "0:00";
    const minutes = Math.floor(timeInSeconds / 60);
    const seconds = Math.floor(timeInSeconds % 60);
    return `${minutes}:${seconds.toString().padStart(2, "0")}`;
  };

  const progress = duration > 0 ? (currentTime / duration) * 100 : 0;

  return (
    <motion.div
      className="voice-audio-player"
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.4 }}
    >
      <div className="player-row">
        <div className="player-icon">
          <Mic2 size={18} />
        </div>
        <div className="waveform-track" onClick={handleSeek}>
          <div className="track-bg">
            {[...Array(20)].map((_, i) => (
              <div
                key={i}
                className={`wave-bar ${isPlaying ? "active" : ""}`}
                style={{
                  animationDelay: `${i * 0.05}s`,
                  height: `${Math.random() * 12 + 4}px`,
                }}
              />
            ))}
          </div>
          <div
            className="track-progress"
            style={{ width: `${Math.min(progress, 100)}%` }}
          />
        </div>
        <motion.button
          className="play-btn"
          onClick={togglePlayPause}
          disabled={!isLoaded}
          whileHover={{ scale: isLoaded ? 1.05 : 1 }}
          whileTap={{ scale: isLoaded ? 0.95 : 1 }}
        >
          {isPlaying ? <Pause size={14} /> : <Play size={14} />}
        </motion.button>
      </div>
      <div className="time-info">
        {formatTime(currentTime)} / {isLoaded ? formatTime(duration) : "..."}
      </div>
      <audio ref={audioRef} src={audioUrl} preload="metadata" />
    </motion.div>
  );
};

export default AudioPlayer;