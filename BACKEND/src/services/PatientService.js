// src/services/PatientService.js
const PatientProfile = require('../models/PatientProfile');
const dbService = require('./DatabaseService');

class PatientService {
  constructor() {
    this.dbInstance = dbService;
    this.db = this.dbInstance.getDb();
    this.currentProfile = null;
    this.loadCurrentProfile();
  }

  async loadCurrentProfile() {
    try {
      const stmt = this.db.prepare(
        'SELECT * FROM patient_profile ORDER BY created_at DESC LIMIT 1'
      );
      const row = stmt.get();

      if (row) {
        this.currentProfile = PatientProfile.fromDB(row);
      }
    } catch (error) {
      console.error('❌ Error loading patient profile:', error.message);
    }
  }

  async createOrUpdateProfile(profileData) {
    try {
      const transaction = this.db.transaction((data) => {
        const profile = new PatientProfile(data);

        const existingProfileId = this.db
          .prepare('SELECT id FROM patient_profile LIMIT 1')
          .get()?.id;

        if (existingProfileId) {
          const stmt = this.db.prepare(`
            UPDATE patient_profile
            SET name = ?, photo_file = ?, description = ?, birth_date = ?, updated_at = strftime('%Y-%m-%d %H:%M:%f', 'now')
            WHERE id = ?
          `);
          stmt.run(
            profile.name,
            profileData.photoFile || this.currentProfile?.photoFile,
            profile.description,
            profile.birthDate,
            existingProfileId
          );
          profile.id = existingProfileId;
        } else {
          const stmt = this.db.prepare(`
            INSERT INTO patient_profile (name, photo_file, description, birth_date)
            VALUES (?, ?, ?, ?)
          `);
          const result = stmt.run(
            profile.name,
            profile.photoFile,
            profile.description,
            profile.birthDate
          );
          profile.id = result.lastInsertRowid;
        }
        return profile;
      });

      const savedProfile = transaction(profileData);
      this.currentProfile = savedProfile;
      return savedProfile;
    } catch (error) {
      console.error('❌ Error creating/updating patient profile:', error.message);
      throw error;
    }
  }

  async getCurrentProfile() {
    if (!this.currentProfile) {
      await this.loadCurrentProfile();
    }
    return this.currentProfile;
  }

  async getStats() {
    try {
      const profile = await this.getCurrentProfile();
      return {
        hasProfile: profile !== null,
        profileName: profile?.name || null,
        profileAge: profile?.getAge() || null,
        createdAt: profile?.createdAt || null,
      };
    } catch (error) {
      console.error('❌ Error getting patient stats:', error.message);
      return { hasProfile: false, profileName: null, profileAge: null, createdAt: null };
    }
  }
}

module.exports = PatientService;