import React, { useState, useEffect } from "react";
import { motion } from "framer-motion";
import "./WelcomeScreen.css";

interface WelcomeScreenProps {
  onEnter: () => void;
  onEnterDashboard: () => void;
}

const WelcomeScreen: React.FC<WelcomeScreenProps> = ({
  onEnter,
  onEnterDashboard,
}) => {
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    setIsReady(true);
  }, []);

  return (
    <div
      style={{
        width: "100vw",
        height: "100vh",
        background:
          "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        padding: "2rem",
        fontFamily:
          "'SF Pro Display', -apple-system, BlinkMacSystemFont, sans-serif",
        color: "white",
        position: "relative",
      }}
    >
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Raleway:wght@300;400;600&display=swap');
        
        @keyframes lights {
          0% { color: hsl(230, 40%, 80%); text-shadow: 0 0 1em hsla(320, 100%, 50%, 0.2), 0 0 0.125em hsla(320, 100%, 60%, 0.3), -1em -0.125em 0.5em hsla(40, 100%, 60%, 0), 1em 0.125em 0.5em hsla(200, 100%, 60%, 0); }
          30% { color: hsl(230, 80%, 90%); text-shadow: 0 0 1em hsla(320, 100%, 50%, 0.5), 0 0 0.125em hsla(320, 100%, 60%, 0.5), -0.5em -0.125em 0.25em hsla(40, 100%, 60%, 0.2), 0.5em 0.125em 0.25em hsla(200, 100%, 60%, 0.4); }
          40% { color: hsl(230, 100%, 95%); text-shadow: 0 0 1em hsla(320, 100%, 50%, 0.5), 0 0 0.125em hsla(320, 100%, 90%, 0.5), -0.25em -0.125em 0.125em hsla(40, 100%, 60%, 0.2), 0.25em 0.125em 0.125em hsla(200, 100%, 60%, 0.4); }
          70% { color: hsl(230, 80%, 90%); text-shadow: 0 0 1em hsla(320, 100%, 50%, 0.5), 0 0 0.125em hsla(320, 100%, 60%, 0.5), 0.5em -0.125em 0.25em hsla(40, 100%, 60%, 0.2), -0.5em 0.125em 0.25em hsla(200, 100%, 60%, 0.4); }
          100% { color: hsl(230, 40%, 80%); text-shadow: 0 0 1em hsla(320, 100%, 50%, 0.2), 0 0 0.125em hsla(320, 100%, 60%, 0.3), 1em -0.125em 0.5em hsla(40, 100%, 60%, 0), -1em 0.125em 0.5em hsla(200, 100%, 60%, 0); }
        }
        .city-nights-title {
          font-family: 'Raleway', sans-serif;
          font-weight: 300;
          animation: lights 5s linear infinite;
        }
      `}</style>

      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `
          radial-gradient(circle at 30% 20%, rgba(156, 39, 176, 0.15) 0%, transparent 50%),
          radial-gradient(circle at 70% 80%, rgba(103, 58, 183, 0.15) 0%, transparent 50%)
        `,
          pointerEvents: "none",
        }}
      />

      <motion.div
        style={{ textAlign: "center", marginBottom: "3rem", zIndex: 1 }}
        initial={{ opacity: 0, scale: 0.8 }}
        animate={{ opacity: isReady ? 1 : 0, scale: isReady ? 1 : 0.8 }}
        transition={{ duration: 0.5, ease: "easeOut" }}
      >
        <h1
          className="city-nights-title"
          style={{
            fontSize: "clamp(3rem, 8vw, 5rem)",
            fontWeight: 300,
            margin: 0,
            lineHeight: 1.1,
            letterSpacing: "-0.02em",
          }}
        >
          Memory Palace
        </h1>
      </motion.div>

      <motion.div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "2rem",
          width: "100%",
          maxWidth: "500px",
          zIndex: 1,
          alignItems: "center",
        }}
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: isReady ? 1 : 0, y: isReady ? 0 : 30 }}
        transition={{ duration: 0.5, delay: 0.4 }}
      >
        <div className="button-container">
          <button className="enter-button" onClick={onEnter}>
            Enter Your Palace
          </button>
        </div>

        <div className="secondary-button-container">
          <button className="family-hub-button" onClick={onEnterDashboard}>
            <svg
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
            >
              <rect x="3" y="3" width="7" height="7" rx="1" />
              <rect x="14" y="3" width="7" height="7" rx="1" />
              <rect x="14" y="14" width="7" height="7" rx="1" />
              <rect x="3" y="14" width="7" height="7" rx="1" />
            </svg>
            Family Hub
          </button>
        </div>
      </motion.div>
    </div>
  );
};

export default WelcomeScreen;
