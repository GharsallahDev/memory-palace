// src/components/ContextualTriggers.tsx
import React from "react";
import { motion } from "framer-motion";
import {
  Sparkles,
  Smile,
  Heart,
  Users,
  Home,
  ChevronRight,
} from "lucide-react";
import "./ContextualTriggers.css";

interface ContextualTriggersProps {
  onTrigger: (query: string, title: string) => void;
  getPartnerName: () => string | null;
}

const ContextualTriggers: React.FC<ContextualTriggersProps> = ({
  onTrigger,
  getPartnerName,
}) => {
  const partnerName = getPartnerName();

  const triggers = [
    {
      query: "Tell me a story about a very happy time.",
      icon: Smile,
      title: "Happy Times",
      subtitle: "A joyful memory",
      color: "rgba(76, 175, 80, 0.2)",
      borderColor: "rgba(76, 175, 80, 0.4)",
    },
    {
      query: partnerName
        ? `Tell me a special story about me and ${partnerName}.`
        : "Tell me a story about love and partnership.",
      icon: Heart,
      title: "My Love",
      subtitle: "Our story together",
      color: "rgba(233, 30, 99, 0.2)",
      borderColor: "rgba(233, 30, 99, 0.4)",
    },
    {
      query: "Show me memories of the children when they were young.",
      icon: Users,
      title: "The Children",
      subtitle: "Watching them grow",
      color: "rgba(255, 193, 7, 0.2)",
      borderColor: "rgba(255, 193, 7, 0.4)",
    },
    {
      query: "Tell me about a happy memory that happened in our home.",
      icon: Home,
      title: "Our Home",
      subtitle: "Life in our special place",
      color: "rgba(103, 58, 183, 0.2)",
      borderColor: "rgba(103, 58, 183, 0.4)",
    },
  ];

  return (
    <motion.div
      className="contextual-triggers"
      initial={{ opacity: 0, y: 30 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -30 }}
      transition={{ duration: 0.6 }}
    >
      <motion.div
        className="triggers-header"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.2, duration: 0.6 }}
      >
        <h3 className="triggers-title">
          <Sparkles size={24} />
          Memory Journeys
        </h3>
        <p className="triggers-subtitle">
          Choose a path to begin a conversation.
        </p>
      </motion.div>

      <div className="triggers-grid">
        {triggers.map((trigger, index) => {
          const IconComponent = trigger.icon;
          return (
            <motion.button
              key={trigger.title}
              className="trigger-card"
              style={{
                background: trigger.color,
                borderColor: trigger.borderColor,
              }}
              initial={{ opacity: 0, y: 20, scale: 0.9 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              transition={{
                delay: 0.4 + index * 0.1,
                duration: 0.5,
                type: "spring",
                stiffness: 100,
              }}
              whileHover={{
                scale: 1.02,
                y: -5,
                boxShadow: `0 10px 25px ${trigger.color}`,
                borderColor: trigger.borderColor.replace("0.4", "0.8"),
              }}
              whileTap={{ scale: 0.98 }}
              onClick={() => onTrigger(trigger.query, trigger.title)}
            >
              <div className="trigger-content">
                <motion.div
                  className="trigger-icon"
                  whileHover={{ scale: 1.1, rotate: 5 }}
                  transition={{ type: "spring", stiffness: 300 }}
                >
                  <IconComponent size={28} />
                </motion.div>
                <div className="trigger-text">
                  <h4 className="trigger-title">{trigger.title}</h4>
                  <p className="trigger-subtitle">{trigger.subtitle}</p>
                </div>
                <motion.div
                  className="trigger-arrow"
                  whileHover={{ x: 5 }}
                  transition={{ type: "spring", stiffness: 300 }}
                >
                  <ChevronRight size={20} />
                </motion.div>
              </div>
            </motion.button>
          );
        })}
      </div>

      <motion.div
        className="triggers-footer"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1, duration: 0.6 }}
      >
        <p className="footer-text">
          Or simply start typing to explore your memories...
        </p>
      </motion.div>
    </motion.div>
  );
};

export default ContextualTriggers;