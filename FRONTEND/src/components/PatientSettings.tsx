// src/components/PatientSettings.tsx
import React, { useState, useEffect, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { User, Camera, Save, X, FileText, Check, Upload } from "lucide-react";
import { PatientApi, initializeApi } from "../utils/ApiUtils";
import "./PatientSettings.css";

interface PatientProfile {
  id?: number | null;
  name: string;
  photoFile?: string | null;
  photoUrl?: string | null;
  description: string;
}

interface PatientSettingsProps {
  isOpen: boolean;
  onClose: () => void;
}

const PatientSettings: React.FC<PatientSettingsProps> = ({
  isOpen,
  onClose,
}) => {
  const [profile, setProfile] = useState<PatientProfile | null>(null);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      loadPatientProfile();
    }
  }, [isOpen]);

  const loadPatientProfile = async () => {
    try {
      setLoading(true);
      setError(null);
      await initializeApi();
      const data = await PatientApi.getPatientProfile();
      setProfile(data);
      if (data?.photoUrl) {
        setPreviewUrl(data.photoUrl);
      }
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Failed to load profile";
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handleImageSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      setSelectedImage(file);
      const url = URL.createObjectURL(file);
      setPreviewUrl(url);
    }
  };

  const handleSave = async () => {
    if (!profile || !profile.name.trim()) {
      setError("Patient name is required.");
      return;
    }

    try {
      setSaving(true);
      setError(null);
      setSuccess(null);

      const savedProfile = await PatientApi.savePatientProfile(
        profile,
        selectedImage || undefined
      );

      if (savedProfile) {
        setProfile(savedProfile);
        if (savedProfile.photoUrl) setPreviewUrl(savedProfile.photoUrl);
        setSelectedImage(null);
        setSuccess("Patient profile saved successfully!");
        setTimeout(() => setSuccess(null), 3000);
      } else {
        throw new Error(
          "Received an invalid profile response from the server."
        );
      }
    } catch (err) {
      const errorMessage =
        err instanceof Error ? err.message : "Failed to save profile";
      setError(errorMessage);
    } finally {
      setSaving(false);
    }
  };

  const handleClose = () => {
    setError(null);
    setSuccess(null);
    onClose();
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <motion.div
        className="patient-settings-overlay"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        onClick={handleClose}
      >
        <motion.div
          className="patient-settings-modal"
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="modal-header">
            <div className="header-icon">
              <User size={24} />
            </div>
            <h2>Patient Profile</h2>
            <button className="close-btn" onClick={handleClose}>
              <X size={20} />
            </button>
          </div>

          <div className="modal-content">
            {loading ? (
              <div className="loading-state">
                <div className="loading-spinner" />
                <p>Loading patient profile...</p>
              </div>
            ) : profile ? (
              <div className="settings-form">
                <div className="form-section photo-section">
                  <label className="section-label">
                    <Camera size={18} /> Profile Photo
                  </label>
                  <div className="photo-upload-area">
                    <div className="photo-preview">
                      {previewUrl ? (
                        <img src={previewUrl} alt="Patient profile" />
                      ) : (
                        <div className="empty-photo">
                          <User size={48} />
                        </div>
                      )}
                    </div>
                    <button
                      type="button"
                      className="upload-btn"
                      onClick={() => fileInputRef.current?.click()}
                    >
                      <Upload size={16} />
                      {previewUrl ? "Change Photo" : "Upload Photo"}
                    </button>
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*"
                      onChange={handleImageSelect}
                      style={{ display: "none" }}
                    />
                  </div>
                </div>

                <div className="form-section">
                  <div className="nebula-input">
                    <input
                      required
                      type="text"
                      value={profile.name}
                      onChange={(e) =>
                        setProfile({ ...profile, name: e.target.value })
                      }
                      className="input"
                      autoComplete="off"
                    />
                    <label className="user-label">Patient Name</label>
                  </div>
                </div>

                <div className="form-section">
                  <div className="nebula-input textarea-container">
                    <textarea
                      required
                      value={profile.description}
                      onChange={(e) =>
                        setProfile({ ...profile, description: e.target.value })
                      }
                      className="input textarea"
                      rows={4}
                    />
                    <label className="user-label">
                      <FileText size={16} /> Description
                    </label>
                  </div>
                </div>
              </div>
            ) : (
              <div className="error-message" style={{ textAlign: "center" }}>
                Could not load profile data.
              </div>
            )}
          </div>

          <div className="modal-footer">
            <AnimatePresence mode="wait">
              {error && (
                <motion.div
                  className="error-message"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                >
                  {error}
                </motion.div>
              )}
              {success && (
                <motion.div
                  className="success-message"
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -10 }}
                >
                  <Check size={16} />
                  {success}
                </motion.div>
              )}
            </AnimatePresence>
            <div className="action-buttons">
              <button
                type="button"
                className="cancel-btn"
                onClick={handleClose}
                disabled={saving}
              >
                Cancel
              </button>
              <button
                type="button"
                className="save-btn"
                onClick={handleSave}
                disabled={saving || !profile?.name.trim()}
              >
                {saving ? (
                  <>
                    <div className="saving-spinner" /> Saving...
                  </>
                ) : (
                  <>
                    <Save size={16} /> Save Profile
                  </>
                )}
              </button>
            </div>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
};

export default PatientSettings;