// src/App.tsx
import { useState } from "react";
import { AnimatePresence } from "framer-motion";
import WelcomeScreen from "./components/WelcomeScreen";
import MemoryPalaceInterface from "./components/MemoryPalaceInterface";
import Dashboard from "./components/Dashboard";

type AppState = "welcome" | "dashboard" | "memoryPalace"

function App() {
  const [currentScreen, setCurrentScreen] = useState<AppState>("welcome");

  const handleEnterMemoryPalace = () => {
    setCurrentScreen("memoryPalace");
  };

  const handleEnterDashboard = () => {
    setCurrentScreen("dashboard");
  };

  const handleBackToWelcome = () => {
    setCurrentScreen("welcome");
  };

  const handleShowCredits = () => {
    setCurrentScreen("credits");
  };

  return (
    <div
      style={{
        width: "100vw",
        height: "100vh",
        overflow: "hidden",
        margin: 0,
        padding: 0,
        fontFamily:
          "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
      }}
    >
      <AnimatePresence mode="wait">
        {currentScreen === "welcome" && (
          <WelcomeScreen
            key="welcome"
            onEnter={handleEnterMemoryPalace}
            onEnterDashboard={handleEnterDashboard}
          />
        )}
        {currentScreen === "dashboard" && (
          <Dashboard
            key="dashboard"
            onEnterMemoryPalace={handleEnterMemoryPalace}
            onBack={handleBackToWelcome}
          />
        )}
        {currentScreen === "memoryPalace" && (
          <MemoryPalaceInterface key="palace" onBack={handleBackToWelcome} />
        )}
        {currentScreen === "credits" && <MemoryPalaceCredits key="credits" />}
      </AnimatePresence>
    </div>
  );
}

export default App;