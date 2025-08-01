// src/components/ProactiveMemoryNotification.tsx
import React, { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { createPortal } from "react-dom";
import {
  Heart,
  Calendar,
  Sparkles,
  Clock,
  Snowflake,
  Image as Photo,
  Video,
  FileText,
  Music,
  ArrowRight,
  X,
  Star,
} from "lucide-react";
import type { ProactiveMemory } from "../services/WebSocketService";
import "./ProactiveMemoryNotification.css";

interface ProactiveMemoryNotificationProps {
  proactiveMemory: ProactiveMemory | null;
  onView: (proactiveId: string) => void;
  onDismiss: (proactiveId: string) => void;
  onClose: () => void;
}

const getTriggerConfig = (triggerType: string) => {
  switch (triggerType) {
    case "on_this_day":
      return {
        icon: <Clock size={24} />,
        color: "#4F46E5",
        bgColor: "rgba(79, 70, 229, 0.1)",
        borderColor: "rgba(79, 70, 229, 0.3)",
        title: "On This Day",
        subtitle: "A memory from the past",
      };
    case "anniversary":
      return {
        icon: <Heart size={24} />,
        color: "#DC2626",
        bgColor: "rgba(220, 38, 38, 0.1)",
        borderColor: "rgba(220, 38, 38, 0.3)",
        title: "Anniversary",
        subtitle: "A special day to remember",
      };
    case "seasonal":
      return {
        icon: <Snowflake size={24} />,
        color: "#059669",
        bgColor: "rgba(5, 150, 105, 0.1)",
        borderColor: "rgba(5, 150, 105, 0.3)",
        title: "Seasonal Memory",
        subtitle: "Perfect for this time of year",
      };
    default:
      return {
        icon: <Calendar size={24} />,
        color: "#6B7280",
        bgColor: "rgba(107, 114, 128, 0.1)",
        borderColor: "rgba(107, 114, 128, 0.3)",
        title: "Memory",
        subtitle: "Something special",
      };
  }
};

const getMemoryIcon = (type: string) => {
  switch (type) {
    case "photo":
      return <Photo size={18} />;
    case "video":
      return <Video size={18} />;
    case "voice":
      return <Music size={18} />;
    case "text":
      return <FileText size={18} />;
    default:
      return <Photo size={18} />;
  }
};

const ProactiveMemoryNotification: React.FC<
  ProactiveMemoryNotificationProps
> = ({ proactiveMemory, onView, onDismiss, onClose }) => {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    setIsVisible(!!proactiveMemory);
  }, [proactiveMemory]);

  const handleView = () => {
    if (proactiveMemory) {
      onView(proactiveMemory.id);
      setIsVisible(false);
      onClose();
    }
  };

  const handleDismiss = () => {
    if (proactiveMemory) {
      onDismiss(proactiveMemory.id);
      setIsVisible(false);
      onClose();
    }
  };

  if (!proactiveMemory || !isVisible) return null;

  const triggerConfig = getTriggerConfig(proactiveMemory.trigger_type);

  return createPortal(
    <AnimatePresence>
      <motion.div
        className="proactive-overlay"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
      >
        <motion.div
          className="proactive-container"
          initial={{ scale: 0.8, opacity: 0, y: 100 }}
          animate={{ scale: 1, opacity: 1, y: 0 }}
          exit={{ scale: 0.8, opacity: 0, y: 100 }}
          transition={{
            type: "spring",
            stiffness: 200,
            damping: 20,
            duration: 0.6,
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="proactive-modal-header">
            <div
              className="trigger-badge"
              style={{
                backgroundColor: triggerConfig.bgColor,
                borderColor: triggerConfig.borderColor,
                color: triggerConfig.color,
              }}
            >
              {triggerConfig.icon}
              <span>{triggerConfig.title}</span>
            </div>
            <button
              className="close-button"
              onClick={handleDismiss}
              aria-label="Close"
            >
              <X size={20} />
            </button>
          </div>
          <div className="proactive-content">
            <div className="content-header">
              <div className="sparkle-icon">
                <Sparkles size={28} />
              </div>
              <h2 className="memory-title">{proactiveMemory.title}</h2>
              <p className="memory-subtitle">{triggerConfig.subtitle}</p>
            </div>
            <div className="memory-description">
              {proactiveMemory.description}
            </div>
            <div className="memories-preview">
              <div className="preview-header">
                <Star size={16} />
                <span>
                  {proactiveMemory.memory_count} special memory
                  {proactiveMemory.memory_count > 1 ? "ies" : ""} ready
                </span>
              </div>
              <div className="memory-cards">
                {proactiveMemory.memories.slice(0, 4).map((memory) => (
                  <motion.div
                    key={memory.id}
                    className="memory-card"
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.2 }}
                  >
                    <div className="memory-icon">
                      {getMemoryIcon(memory.type)}
                    </div>
                    <div className="memory-info">
                      <div className="memory-name">{memory.title}</div>
                      <div className="memory-type">{memory.type}</div>
                    </div>
                  </motion.div>
                ))}
                {proactiveMemory.memory_count > 4 && (
                  <div className="more-memories">
                    <div className="more-count">
                      +{proactiveMemory.memory_count - 4}
                    </div>
                    <div className="more-text">more</div>
                  </div>
                )}
              </div>
            </div>
            {proactiveMemory.is_queued && (
              <div className="queued-badge">
                <Clock size={16} />
                <span>Prepared while you were away</span>
              </div>
            )}
          </div>
          <div className="proactive-actions">
            <motion.button
              className="proactive-action-btn secondary-btn"
              onClick={handleDismiss}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
            >
              Maybe later
            </motion.button>
            <motion.button
              className="proactive-action-btn primary-btn"
              onClick={handleView}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
            >
              <Heart size={20} />
              <span>Let's explore together</span>
              <ArrowRight size={18} />
            </motion.button>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>,
    document.body
  );
};

export default ProactiveMemoryNotification;