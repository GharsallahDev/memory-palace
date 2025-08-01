// src/components/SharedHeader.tsx
import React from "react";
import { motion } from "framer-motion";
import { ArrowLeft, RefreshCw, Settings, User } from "lucide-react";
import "./SharedHeader.css";

interface HeaderAction {
  icon: "refresh" | "settings" | "user";
  onClick: () => void;
  title: string;
  disabled?: boolean;
  loading?: boolean;
}

interface SharedHeaderProps {
  onBack: () => void;
  title?: string;
  subtitle?: string;
  actions?: HeaderAction[];
  patientName?: string;
  isProcessing?: boolean;
}

const SharedHeader: React.FC<SharedHeaderProps> = ({
  onBack,
  title = "Memory Palace",
  subtitle,
  actions = [],
  patientName,
  isProcessing = false,
}) => {
  const renderIcon = (iconType: string, loading?: boolean) => {
    if (loading) {
      return <div className="loading-spinner-small" />;
    }
    switch (iconType) {
      case "refresh":
        return <RefreshCw size={20} />;
      case "settings":
        return <Settings size={20} />;
      case "user":
        return <User size={20} />;
      default:
        return <Settings size={20} />;
    }
  };

  const displaySubtitle = patientName ? `Welcome, ${patientName}` : subtitle;

  return (
    <motion.header
      className="shared-header"
      initial={{ y: -30, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ delay: 0.2, duration: 0.6 }}
    >
      <div className="header-content">
        <div className="header-left">
          <button className="back-btn" onClick={onBack} title="Go Back">
            <ArrowLeft size={24} />
          </button>
        </div>

        <div className="header-center">
          <div className="logo-container">
            <img
              src={isProcessing ? "/logo.gif" : "/logo.png"}
              alt="Memory Palace Logo"
              className="logo-image"
            />
          </div>
          <div className="header-text">
            <h1 className="city-nights-title">{title}</h1>
            {displaySubtitle && (
              <p className="header-subtitle">{displaySubtitle}</p>
            )}
          </div>
        </div>

        <div className="header-actions">
          {actions.map((action, index) => (
            <button
              key={index}
              className={`action-btn action-btn-${action.icon}`}
              onClick={action.onClick}
              title={action.title}
              disabled={action.disabled}
            >
              {renderIcon(action.icon, action.loading)}
            </button>
          ))}
        </div>
      </div>
    </motion.header>
  );
};

export default SharedHeader;