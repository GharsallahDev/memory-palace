// src/services/MemoryService.js
const Memory = require('../models/Memory');
const dbService = require('./DatabaseService');
const ProactiveAnalysisService = require('./ProactiveAnalysisService');
const PatientService = require('./PatientService');
const axios = require('axios');

function createEmbeddingSummary(memory) {
  const parts = [];
  parts.push(`Type: ${memory.type}.`);
  parts.push(`Title: ${memory.title}.`);
  if (memory.description) parts.push(`Description: ${memory.description}.`);
  if (memory.content) parts.push(`Content: ${memory.content}.`);

  const peopleNames = memory.getPeopleNames();
  if (peopleNames.length > 0) parts.push(`People present: ${peopleNames.join(', ')}.`);

  if (memory.whenWasThis) parts.push(`Time: ${memory.whenWasThis}.`);
  if (memory.whereWasThis) parts.push(`Location: ${memory.whereWasThis}.`);

  if (memory.transcription_text)
    parts.push(`Transcription of audio: ${memory.transcription_text}.`);

  return parts.join(' ');
}

class MemoryService {
  constructor(personService, fileService) {
    this.db = dbService.getDb();
    this.personService = personService;
    this.fileService = fileService;
    this.proactiveAnalysisService = new ProactiveAnalysisService();
    this.patientService = new PatientService();
  }

  async _createMemory(
    memoryData,
    fileInfo = {},
    faceTags = [],
    peopleIds = [],
    perceptualHash = null,
    transcriptionText = null
  ) {
    const transaction = this.db.transaction(async (data) => {
      const peopleNames = [];
      const primaryProfileId = -1;

      if (peopleIds.includes(primaryProfileId)) {
        const patientProfile = await this.patientService.getCurrentProfile();
        if (patientProfile) {
          peopleNames.push(patientProfile.name);
        }
      }

      const regularPeopleIds = peopleIds.filter((id) => id !== primaryProfileId);
      if (regularPeopleIds.length > 0) {
        const regularPeopleNames = regularPeopleIds
          .map((id) => this.personService.findById(id)?.name)
          .filter(Boolean);
        peopleNames.push(...regularPeopleNames);
      }

      const whoWasThere = peopleNames.join(', ');

      const memory = new Memory({ ...data, ...fileInfo, whoWasThere });
      const dbData = memory.toDBInsert();
      dbData.perceptual_hash = perceptualHash;
      dbData.transcription_text = transcriptionText;

      dbData.anniversary_type = null;
      dbData.seasonal_tags = null;
      dbData.proactive_score = 0;

      const memoryStmt = this.db.prepare(`
        INSERT INTO memories (type, title, description, content, who_was_there, when_was_this, where_was_this, context, duration, timestamp, device_name, image_file, audio_file, video_file, thumbnail_file, perceptual_hash, transcription_text, anniversary_type, seasonal_tags, proactive_score)
        VALUES (@type, @title, @description, @content, @who_was_there, @when_was_this, @where_was_this, @context, @duration, @timestamp, @device_name, @image_file, @audio_file, @video_file, @thumbnail_file, @perceptual_hash, @transcription_text, @anniversary_type, @seasonal_tags, @proactive_score)
      `);
      const result = memoryStmt.run(dbData);
      memory.id = result.lastInsertRowid;

      if (transcriptionText) {
        memory.transcription_text = transcriptionText;
      }

      if (regularPeopleIds.length > 0) {
        const linkStmt = this.db.prepare(
          'INSERT OR IGNORE INTO memory_people (memory_id, person_id) VALUES (?, ?)'
        );
        for (const personId of regularPeopleIds) {
          linkStmt.run(memory.id, personId);
        }
      }

      if (faceTags && faceTags.length > 0) {
        const tagStmt = this.db.prepare(`
          INSERT INTO face_tags (id, memory_id, person_id, confidence, bounding_box, detected_at, is_manual)
          VALUES (@id, @memory_id, @person_id, @confidence, @bounding_box, @detected_at, @is_manual)
        `);
        for (const tag of faceTags) {
          let personServerId = tag.personServerId || null;
          if (personServerId === primaryProfileId) {
            personServerId = null;
          }

          if (!personServerId && tag.personName) {
            const person = this.personService.findByName(tag.personName);
            if (person) {
              personServerId = person.id;
            }
          }
          tagStmt.run({
            id: tag.id,
            memory_id: memory.id,
            person_id: personServerId,
            confidence: tag.confidence,
            bounding_box: JSON.stringify(tag.boundingBox),
            detected_at: tag.detectedAt || new Date().toISOString(),
            is_manual: tag.isManual ? 1 : 0,
          });
          if (personServerId) {
            this.db
              .prepare('INSERT OR IGNORE INTO memory_people (memory_id, person_id) VALUES (?, ?)')
              .run(memory.id, personServerId);
          }
        }
      }

      if (memory.type === 'photo') {
        this.db
          .prepare("INSERT INTO ai_generation_queue (memory_id, task_type) VALUES (?, 'caption')")
          .run(memory.id);
      }

      return memory;
    });

    const createdMemory = await transaction(memoryData);

    try {
      const aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';
      const summaryText = createEmbeddingSummary(createdMemory);

      if (summaryText.trim()) {
        const response = await axios.post(`${aiServiceUrl}/generate-embedding`, {
          text: summaryText,
        });
        const { vector } = response.data;

        if (vector && vector.length > 0) {
          this.db
            .prepare('UPDATE memories SET embedding = ? WHERE id = ?')
            .run(JSON.stringify(vector), createdMemory.id);
        }
      }
    } catch (error) {
      console.error(
        `❌ Synchronous embedding failed for memory ${createdMemory.id}:`,
        error.message
      );
    }

    this._performProactiveAnalysisAsync(createdMemory);

    return createdMemory;
  }

  async _performProactiveAnalysisAsync(memory) {
    try {
      const analysis = await this.proactiveAnalysisService.analyzeMemory(memory);

      this.db
        .prepare(
          `
        UPDATE memories 
        SET anniversary_type = ?, seasonal_tags = ?, proactive_score = ? 
        WHERE id = ?
      `
        )
        .run(
          analysis.anniversary_type,
          analysis.seasonal_tags.length > 0 ? JSON.stringify(analysis.seasonal_tags) : null,
          analysis.proactive_score,
          memory.id
        );
    } catch (error) {
      console.error(`❌ Proactive analysis failed for memory ${memory.id}:`, error.message);
    }
  }

  async createPhotoMemory(
    memoryData,
    imageFile,
    faceTags = [],
    peopleIds = [],
    perceptualHash = null
  ) {
    return await this._createMemory(
      { ...memoryData, type: 'photo' },
      { imageFile },
      faceTags,
      peopleIds,
      perceptualHash
    );
  }

  async createVoiceMemory(memoryData, audioFile, peopleIds = [], transcriptionText = null) {
    return await this._createMemory(
      { ...memoryData, type: 'voice' },
      { audioFile },
      [],
      peopleIds,
      null,
      transcriptionText
    );
  }

  async createVideoMemory(memoryData, videoFile, peopleIds = []) {
    const thumbnailFile = await this.fileService.generateVideoThumbnail(videoFile);
    return await this._createMemory(
      { ...memoryData, type: 'video' },
      { videoFile, thumbnailFile },
      [],
      peopleIds
    );
  }

  async createTextMemory(memoryData, peopleIds = []) {
    return await this._createMemory({ ...memoryData, type: 'text' }, {}, [], peopleIds);
  }

  _enrichMemoryWithTags(memoryRow) {
    if (!memoryRow) {
      return null;
    }
    try {
      const faceTagsStmt = this.db.prepare(
        `SELECT ft.id, ft.person_id, p.name as person_name, ft.confidence, ft.bounding_box, ft.detected_at, ft.is_manual FROM face_tags ft LEFT JOIN people p ON ft.person_id = p.id WHERE ft.memory_id = ?`
      );
      const faceTagRows = faceTagsStmt.all(memoryRow.id);
      const faceTags = faceTagRows.map((row) => {
        let boundingBox;
        try {
          boundingBox = JSON.parse(row.bounding_box);
        } catch (e) {
          boundingBox = { x: 0, y: 0, width: 0, height: 0 };
        }
        return {
          id: row.id,
          personId: row.person_id,
          personName: row.person_name,
          confidence: row.confidence,
          boundingBox: boundingBox,
          detectedAt: row.detected_at,
          taggedAt: row.person_name ? row.detected_at : null,
        };
      });

      const memory = Memory.fromDB({ ...memoryRow, faceTags });
      memory.transcription_text = memoryRow.transcription_text;
      memory.anniversary_type = memoryRow.anniversary_type;
      memory.seasonal_tags = memoryRow.seasonal_tags;
      memory.proactive_score = memoryRow.proactive_score;

      return memory;
    } catch (error) {
      console.error(
        `❌ An error occurred in _enrichMemoryWithTags for memory ID ${memoryRow.id}:`,
        error
      );
      return null;
    }
  }

  findById(id) {
    try {
      const stmt = this.db.prepare('SELECT * FROM memories WHERE id = ?');
      const row = stmt.get(id);
      return this._enrichMemoryWithTags(row);
    } catch (error) {
      console.error(`❌ Error in findById:`, error);
      return null;
    }
  }

  getAllMemories() {
    try {
      const stmt = this.db.prepare('SELECT * FROM memories ORDER BY timestamp DESC');
      const rows = stmt.all();
      return rows.map((row) => this._enrichMemoryWithTags(row)).filter(Boolean);
    } catch (error) {
      console.error(`❌ Error in getAllMemories:`, error);
      return [];
    }
  }

  getMemoriesForPerson(personId) {
    const stmt = this.db.prepare(`
      SELECT m.*
      FROM memories m
      JOIN memory_people mp ON m.id = mp.memory_id
      WHERE mp.person_id = ?
      ORDER BY m.timestamp DESC
    `);
    const memoryRows = stmt.all(personId);
    return memoryRows.map((row) => this._enrichMemoryWithTags(row)).filter(Boolean);
  }

  async updateMemory(id, updates) {
    const memory = this.findById(id);
    if (!memory) {
      throw new Error(`Memory with ID ${id} not found.`);
    }

    memory.updateMetadata(updates);

    const updateStmt = this.db.prepare(
      `UPDATE memories SET title = ?, description = ?, content = ?, who_was_there = ?, when_was_this = ?, where_was_this = ?, context = ? WHERE id = ?`
    );

    updateStmt.run(
      memory.title,
      memory.description,
      memory.content,
      memory.whoWasThere,
      memory.whenWasThis,
      memory.whereWasThis,
      memory.context,
      id
    );

    try {
      const aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';
      const summaryText = createEmbeddingSummary(memory);

      if (summaryText.trim()) {
        const response = await axios.post(`${aiServiceUrl}/generate-embedding`, {
          text: summaryText,
        });
        const { vector } = response.data;

        if (vector && vector.length > 0) {
          this.db
            .prepare('UPDATE memories SET embedding = ? WHERE id = ?')
            .run(JSON.stringify(vector), id);
        }
      }
    } catch (error) {
      console.error(`❌ Failed to update embedding for memory ${id}:`, error.message);
    }

    this._performProactiveAnalysisAsync(memory);

    return memory;
  }

  async deleteMemory(id) {
    const memory = this.findById(id);
    if (!memory) throw new Error(`Memory with ID ${id} not found.`);

    if (memory.imageFile) await this.fileService.deleteFile(memory.imageFile);
    if (memory.audioFile) await this.fileService.deleteFile(memory.audioFile);
    if (memory.videoFile) await this.fileService.deleteFile(memory.videoFile);
    if (memory.thumbnailFile) await this.fileService.deleteFile(memory.thumbnailFile);

    const stmt = this.db.prepare('DELETE FROM memories WHERE id = ?');
    stmt.run(id);
    return true;
  }

  generateMemoryURLs(memory, serverIP, port) {
    try {
      const baseURL = `http://${serverIP}:${port}/uploads`;
      const memoryJSON = memory.toJSON();

      if (memory.transcription_text) {
        memoryJSON.transcription_text = memory.transcription_text;
      }
      if (memory.anniversary_type) {
        memoryJSON.anniversary_type = memory.anniversary_type;
      }
      if (memory.seasonal_tags) {
        memoryJSON.seasonal_tags = memory.seasonal_tags;
      }
      if (memory.proactive_score !== undefined) {
        memoryJSON.proactive_score = memory.proactive_score;
      }

      return {
        ...memoryJSON,
        imageUrl: memory.imageFile ? `${baseURL}/${memory.imageFile}` : null,
        audioUrl: memory.audioFile ? `${baseURL}/${memory.audioFile}` : null,
        videoUrl: memory.videoFile ? `${baseURL}/${memory.videoFile}` : null,
        thumbnailUrl: memory.thumbnailFile ? `${baseURL}/${memory.thumbnailFile}` : null,
      };
    } catch (error) {
      console.error(`❌ Error generating URLs for memory:`, error);
      return null;
    }
  }

  getStatistics() {
    const stmt = this.db.prepare(
      `SELECT (SELECT COUNT(*) FROM memories) as totalMemories, (SELECT COUNT(*) FROM memories WHERE type = 'photo') as photoCount, (SELECT COUNT(*) FROM memories WHERE type = 'voice') as voiceCount, (SELECT COUNT(*) FROM memories WHERE type = 'video') as videoCount, (SELECT COUNT(*) FROM memories WHERE type = 'text') as textCount`
    );
    const stats = stmt.get();
    const recentStmt = this.db.prepare(
      'SELECT id, title, type, timestamp, device_name FROM memories ORDER BY timestamp DESC LIMIT 5'
    );
    const recentMemories = recentStmt.all();
    return { ...stats, recentMemories };
  }

  findMemoryByPHash(pHash) {
    const stmt = this.db.prepare(
      "SELECT * FROM memories WHERE perceptual_hash = ? AND type = 'photo' LIMIT 1"
    );
    const row = stmt.get(pHash);
    return row ? this._enrichMemoryWithTags(row) : null;
  }

  findRelatedMemoriesForPeople(personIds, limit = 5) {
    if (!personIds || personIds.length === 0) {
      return [];
    }

    let contextBundle = [];
    const seenMemoryIds = new Set();
    const placeholders = personIds.map(() => '?').join(',');

    const groupStmt = this.db.prepare(`
      SELECT m.* FROM memories m
      JOIN memory_people mp ON m.id = mp.memory_id
      WHERE mp.person_id IN (${placeholders}) AND m.type IN ('photo', 'video', 'audio')
      GROUP BY m.id
      HAVING COUNT(DISTINCT mp.person_id) = ?
      ORDER BY m.timestamp DESC
      LIMIT ?
    `);
    const groupMemories = groupStmt.all(...personIds, personIds.length, limit);
    for (const row of groupMemories) {
      if (contextBundle.length < limit && !seenMemoryIds.has(row.id)) {
        contextBundle.push(row);
        seenMemoryIds.add(row.id);
      }
    }

    if (contextBundle.length < limit) {
      const overlapStmt = this.db.prepare(`
        SELECT m.*, COUNT(DISTINCT mp.person_id) as person_count
        FROM memories m
        JOIN memory_people mp ON m.id = mp.memory_id
        WHERE mp.person_id IN (${placeholders}) AND m.type IN ('photo', 'video', 'audio')
        GROUP BY m.id
        ORDER BY person_count DESC, m.timestamp DESC
        LIMIT 10
      `);
      const overlapMemories = overlapStmt.all(...personIds);
      for (const row of overlapMemories) {
        if (contextBundle.length < limit && !seenMemoryIds.has(row.id)) {
          contextBundle.push(row);
          seenMemoryIds.add(row.id);
        }
      }
    }

    if (contextBundle.length < limit) {
      const representedPeople = new Set(
        contextBundle.flatMap((row) => this.getPeopleIdsForRow(row.id))
      );
      const unrepresentedPeople = personIds.filter((id) => !representedPeople.has(id));
      for (const personId of unrepresentedPeople) {
        if (contextBundle.length >= limit) break;
        const seenIdsString = Array.from(seenMemoryIds).join(',') || '0';
        const individualStmt = this.db.prepare(`
          SELECT m.* FROM memories m
          JOIN memory_people mp ON m.id = mp.memory_id
          WHERE mp.person_id = ? AND m.type IN ('photo', 'video', 'audio') AND m.id NOT IN (${seenIdsString})
          ORDER BY m.timestamp DESC
          LIMIT 1
        `);
        const memory = individualStmt.get(personId);
        if (memory && !seenMemoryIds.has(memory.id)) {
          contextBundle.push(memory);
          seenMemoryIds.add(memory.id);
        }
      }
    }

    return contextBundle.map((row) => this._enrichMemoryWithTags(row)).filter(Boolean);
  }

  getPeopleIdsForRow(memoryId) {
    const stmt = this.db.prepare('SELECT person_id FROM memory_people WHERE memory_id = ?');
    return stmt.all(memoryId).map((r) => r.person_id);
  }

  prepareMemoryForAI(memory) {
    if (!memory) return null;

    const peopleNames = memory.getPeopleNames();
    const peopleDetails = peopleNames.map((name) => {
      const person = this.personService.findByName(name);
      return {
        name: name,
        relationship: person ? person.relationship : null,
      };
    });

    return {
      memory_id: memory.id.toString(),
      type: memory.type,
      title: memory.title,
      description: memory.description || '',
      generated_caption: memory.generated_caption || null,
      content: memory.content || '',
      people: peopleDetails,
      date: memory.whenWasThis || memory.getFormattedTimestamp(),
      location: memory.whereWasThis || null,
    };
  }
}

module.exports = MemoryService;