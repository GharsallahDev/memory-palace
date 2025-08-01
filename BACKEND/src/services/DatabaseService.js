// src/services/DatabaseService.js
const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

class DatabaseService {
  constructor() {
    if (DatabaseService.instance) {
      return DatabaseService.instance;
    }

    const dataDir = path.join(__dirname, '../../data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir);
    }

    const avatarsDir = path.join(__dirname, '../../uploads/avatars');
    if (!fs.existsSync(avatarsDir)) {
      fs.mkdirSync(avatarsDir, { recursive: true });
    }

    this.dbPath = path.join(dataDir, 'memory_palace.db');

    try {
      this.db = new Database(this.dbPath);
      this.db.pragma('journal_mode = WAL');
      this.db.pragma('foreign_keys = ON');
      this.initializeSchema();
      console.log('✅ Database connection established and schema is up to date.');
    } catch (error) {
      console.error('❌ FATAL: Could not connect to or initialize database.', error);
      throw error;
    }

    DatabaseService.instance = this;
  }

  initializeSchema() {
    const transaction = this.db.transaction(() => {
      this.db.exec(`
        CREATE TABLE IF NOT EXISTS memories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL CHECK (type IN ('photo', 'voice', 'video', 'text')),
          title TEXT NOT NULL,
          description TEXT DEFAULT '',
          content TEXT DEFAULT '',
          who_was_there TEXT DEFAULT '',
          when_was_this TEXT DEFAULT '',
          where_was_this TEXT DEFAULT '',
          context TEXT DEFAULT '',
          duration REAL DEFAULT NULL,
          timestamp TEXT NOT NULL,
          device_name TEXT NOT NULL,
          image_file TEXT DEFAULT NULL,
          audio_file TEXT DEFAULT NULL,
          video_file TEXT DEFAULT NULL,
          thumbnail_file TEXT DEFAULT NULL,
          generated_caption TEXT DEFAULT NULL,
          transcription_text TEXT DEFAULT NULL,
          transcription_timestamps TEXT DEFAULT NULL,
          perceptual_hash TEXT DEFAULT NULL,
          embedding BLOB DEFAULT NULL,
          anniversary_type TEXT DEFAULT NULL,
          seasonal_tags TEXT DEFAULT NULL,
          proactive_score REAL DEFAULT 0,
          created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
          updated_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
        )
      `);

      this.db.exec(`
        CREATE TABLE IF NOT EXISTS people (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          relationship TEXT,
          created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
          last_seen_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
          device_name TEXT DEFAULT 'Unknown Device',
          avatar_file TEXT DEFAULT NULL,
          avatar_source_memory_id INTEGER DEFAULT NULL,
          FOREIGN KEY (avatar_source_memory_id) REFERENCES memories(id) ON DELETE SET NULL
        )
      `);

      this.db.exec(`
        CREATE TABLE IF NOT EXISTS face_tags (
          id TEXT PRIMARY KEY, memory_id INTEGER NOT NULL, person_id INTEGER DEFAULT NULL, person_name TEXT DEFAULT NULL, confidence REAL NOT NULL, bounding_box TEXT NOT NULL, face_embedding BLOB DEFAULT NULL, detected_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')), is_manual BOOLEAN DEFAULT FALSE, FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE, FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE SET NULL
        )
      `);

      this.db.exec(`
        CREATE TABLE IF NOT EXISTS memory_people (
          id INTEGER PRIMARY KEY AUTOINCREMENT, memory_id INTEGER NOT NULL, person_id INTEGER NOT NULL, relationship_type TEXT DEFAULT 'appears_in', confidence REAL DEFAULT 1.0, created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')), FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE, FOREIGN KEY (person_id) REFERENCES people(id) ON DELETE CASCADE, UNIQUE(memory_id, person_id, relationship_type)
        )
      `);

      this.db.exec(`
        CREATE TABLE IF NOT EXISTS patient_profile (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, photo_file TEXT DEFAULT NULL, description TEXT DEFAULT '', birth_date TEXT DEFAULT NULL, created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')), updated_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
        )
      `);

      this.db.exec(`
        CREATE TABLE IF NOT EXISTS ai_generation_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          memory_id INTEGER NOT NULL,
          task_type TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pending',
          attempts INTEGER DEFAULT 0,
          created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
          processed_at DATETIME DEFAULT NULL,
          error_message TEXT DEFAULT NULL,
          FOREIGN KEY (memory_id) REFERENCES memories(id) ON DELETE CASCADE
        )
      `);

      this.db.exec(`
        CREATE TABLE IF NOT EXISTS proactive_memories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          trigger_type TEXT NOT NULL,
          trigger_date DATE NOT NULL,
          memory_ids TEXT NOT NULL,
          delivered_at DATETIME DEFAULT NULL,
          viewed_at DATETIME DEFAULT NULL,
          dismissed_at DATETIME DEFAULT NULL,
          user_response TEXT DEFAULT NULL,
          created_at DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
        )
      `);

      // Migration checks for existing installations
      const tableInfo = this.db.prepare(`PRAGMA table_info(proactive_memories)`).all();
      const hasViewedAt = tableInfo.some((col) => col.name === 'viewed_at');
      const hasDismissedAt = tableInfo.some((col) => col.name === 'dismissed_at');

      if (!hasViewedAt) {
        this.db.exec(`ALTER TABLE proactive_memories ADD COLUMN viewed_at DATETIME DEFAULT NULL`);
      }

      if (!hasDismissedAt) {
        this.db.exec(
          `ALTER TABLE proactive_memories ADD COLUMN dismissed_at DATETIME DEFAULT NULL`
        );
      }
    });

    transaction();
  }

  getDb() {
    return this.db;
  }

  close() {
    if (this.db) {
      this.db.close();
      console.log('Database connection closed.');
    }
  }
}

const instance = new DatabaseService();
Object.freeze(instance);

module.exports = instance;