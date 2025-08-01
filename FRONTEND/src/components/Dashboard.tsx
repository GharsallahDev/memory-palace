// src/components/Dashboard.tsx
import React, { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  QrCode,
  Users,
  Image,
  Video,
  Music,
  FileText,
  Wifi,
  Activity,
} from "lucide-react";
import SharedHeader from "./SharedHeader";
import PatientSettings from "./PatientSettings";
import { MemoryApi, initializeApi } from "../utils/ApiUtils";
import "./Dashboard.css";

interface DashboardProps {
  onEnterMemoryPalace: () => void;
  onBack: () => void;
}

interface HubStats {
  total: number;
  photos: number;
  voices: number;
  videos: number;
  texts: number;
  people: number;
  connectedDevices: number;
}

interface HubConfig {
  serverIP: string;
  port: number;
  authToken: string;
}

const Dashboard: React.FC<DashboardProps> = ({
  onEnterMemoryPalace,
  onBack,
}) => {
  const [stats, setStats] = useState<HubStats | null>(null);
  const [hubConfig, setHubConfig] = useState<HubConfig | null>(null);
  const [showPatientSettings, setShowPatientSettings] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [qrCodeUrl, setQrCodeUrl] = useState<string>("");

  useEffect(() => {
    const loadDashboardData = async () => {
      try {
        setLoading(true);
        setError(null);

        await initializeApi();
        const statsData = await MemoryApi.getMemoryStats();
        setStats(statsData);

        const response = await fetch("http://localhost:3000/api/config");
        if (!response.ok)
          throw new Error("Could not fetch hub config for display.");
        const config = await response.json();
        setHubConfig(config);

        const qrData = JSON.stringify({
          serverIP: config.serverIP,
          port: config.port,
          authToken: config.authToken,
        });
        const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(
          qrData
        )}`;
        setQrCodeUrl(qrUrl);
      } catch (err) {
        const errorMessage =
          err instanceof Error ? err.message : "An unknown error occurred.";
        setError(
          `Failed to load dashboard data. Is the backend server running?`
        );
      } finally {
        setLoading(false);
      }
    };

    loadDashboardData();
  }, []);

  const handleRefresh = async () => {
    try {
      setLoading(true);
      setError(null);
      const statsData = await MemoryApi.getMemoryStats();
      setStats(statsData);
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "An unknown error occurred.";
      setError(`Failed to refresh data. ${errorMessage}`);
    } finally {
      setLoading(false);
    }
  };

  if (loading && !stats) {
    return (
      <div className="dashboard-loading">
        <div className="loading-spinner" />
        <p>Connecting to Memory Palace Hub...</p>
      </div>
    );
  }

  const headerActions = [
    {
      icon: "refresh" as const,
      onClick: handleRefresh,
      title: "Refresh Data",
      disabled: loading,
      loading: loading,
    },
    {
      icon: "user" as const,
      onClick: () => setShowPatientSettings(true),
      title: "Patient Settings",
    },
  ];

  return (
    <motion.div
      className="dashboard"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0, scale: 0.95 }}
      transition={{ duration: 0.5 }}
    >
      <SharedHeader onBack={onBack} actions={headerActions} />

      <div className="dashboard-content">
        <AnimatePresence>
          {error && (
            <motion.div
              className="error-banner"
              initial={{ opacity: 0, y: -20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -20 }}
            >
              <Activity size={20} />
              {error}
              <button onClick={() => setError(null)}>✕</button>
            </motion.div>
          )}
        </AnimatePresence>

        <div className="dashboard-grid">
          <motion.div
            className="dashboard-card stats-card"
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ delay: 0.4, duration: 0.6 }}
          >
            <div className="card-header">
              <Activity size={24} />
              <h3>Memory Collection</h3>
            </div>
            <div className="card-body">
              <div className="stats-grid">
                <div className="stat-item">
                  <div className="stat-icon total">
                    <Activity size={20} />
                  </div>
                  <div className="stat-content">
                    <div className="stat-number">{stats?.total || 0}</div>
                    <div className="stat-label">Total Memories</div>
                  </div>
                </div>
                <div className="stat-item">
                  <div className="stat-icon photos">
                    <Image size={20} />
                  </div>
                  <div className="stat-content">
                    <div className="stat-number">{stats?.photos || 0}</div>
                    <div className="stat-label">Photos</div>
                  </div>
                </div>
                <div className="stat-item">
                  <div className="stat-icon videos">
                    <Video size={20} />
                  </div>
                  <div className="stat-content">
                    <div className="stat-number">{stats?.videos || 0}</div>
                    <div className="stat-label">Videos</div>
                  </div>
                </div>
                <div className="stat-item">
                  <div className="stat-icon voices">
                    <Music size={20} />
                  </div>
                  <div className="stat-content">
                    <div className="stat-number">{stats?.voices || 0}</div>
                    <div className="stat-label">Stories</div>
                  </div>
                </div>
                <div className="stat-item">
                  <div className="stat-icon texts">
                    <FileText size={20} />
                  </div>
                  <div className="stat-content">
                    <div className="stat-number">{stats?.texts || 0}</div>
                    <div className="stat-label">Texts</div>
                  </div>
                </div>
                <div className="stat-item">
                  <div className="stat-icon people">
                    <Users size={20} />
                  </div>
                  <div className="stat-content">
                    <div className="stat-number">{stats?.people || 0}</div>
                    <div className="stat-label">People</div>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>

          <motion.div
            className="dashboard-card qr-card featured"
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ delay: 0.5, duration: 0.6 }}
          >
            <div className="card-header">
              <QrCode size={24} />
              <h3>Device Connection</h3>
            </div>
            <div className="card-body">
              <div className="qr-content">
                {qrCodeUrl ? (
                  <div className="qr-code-container">
                    <img src={qrCodeUrl} alt="Setup QR Code" />
                  </div>
                ) : (
                  <div className="qr-placeholder">
                    <QrCode size={48} />
                    <p>Loading QR Code...</p>
                  </div>
                )}
                <p className="qr-instructions">
                  Scan with the iOS app to connect family devices securely.
                </p>
              </div>
            </div>
          </motion.div>

          <motion.div
            className="dashboard-card status-card"
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ delay: 0.6, duration: 0.6 }}
          >
            <div className="card-header">
              <Wifi size={24} />
              <h3>Hub Status</h3>
            </div>
            <div className="card-body">
              <div className="status-content">
                <div className="status-item">
                  <span className="status-label">Server IP</span>
                  <span className="status-value">
                    {hubConfig?.serverIP || "..."}
                  </span>
                </div>
                <div className="status-item">
                  <span className="status-label">Port</span>
                  <span className="status-value">
                    {hubConfig?.port || "..."}
                  </span>
                </div>
                <div className="status-item">
                  <span className="status-label">Session ID</span>
                  <span className="status-value">
                    {hubConfig?.authToken.substring(0, 8) || "..."}...
                  </span>
                </div>
                <div className="status-item connected">
                  <span className="status-label">Connected Devices</span>
                  <span className="status-value status-connected">
                    <div className="status-dot" />
                    {stats?.connectedDevices || 1} device
                    {stats?.connectedDevices !== 1 ? "s" : ""}
                  </span>
                </div>
              </div>
            </div>
          </motion.div>
        </div>
      </div>

      <PatientSettings
        isOpen={showPatientSettings}
        onClose={() => setShowPatientSettings(false)}
      />
    </motion.div>
  );
};

export default Dashboard;