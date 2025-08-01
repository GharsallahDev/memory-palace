// src/routes/memories.js
const express = require('express');
const multer = require('multer');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const axios = require('axios');
const FormData = require('form-data');
const { randomUUID } = require('crypto');
const { getLocalIP, cosineSimilarity } = require('../utils/helpers');
const pHash = require('sharp-phash');

const diskStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const now = new Date();
    const year = now.getFullYear().toString();
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const uploadDir = path.join('./uploads', year, month);
    fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    cb(null, `${timestamp}-${sanitizedName}`);
  },
});
const uploadToDisk = multer({ storage: diskStorage, limits: { fileSize: 100 * 1024 * 1024 } });
const memoryStorage = multer.memoryStorage();
const uploadToMemory = multer({ storage: memoryStorage, limits: { fileSize: 10 * 1024 * 1024 } });

const getDbPath = (file) => {
  if (!file) return null;
  return path.relative('./uploads', file.path).replace(/\\/g, '/');
};
const parseJsonField = (field) => {
  if (!field || typeof field !== 'string') return [];
  try {
    return JSON.parse(field);
  } catch (e) {
    return [];
  }
};

function prepareMemoryForAISimple(memory, memoryService) {
  if (!memory) return null;

  const peopleNames = memory.getPeopleNames();
  const peopleDetails = peopleNames.map((name) => {
    const person = memoryService.personService.findByName(name);
    if (person && person.relationship) {
      return `${name} (${person.relationship})`;
    }
    return name;
  });

  const peopleText = peopleDetails.length > 0 ? ` with ${peopleDetails.join(', ')}` : '';
  const timeText = memory.whenWasThis ? ` on ${memory.whenWasThis}` : '';
  const locationText = memory.whereWasThis ? ` at ${memory.whereWasThis}` : '';

  let description = '';
  if (memory.type === 'photo') {
    description = `Photo: "${memory.title}"${peopleText}${timeText}${locationText}`;
    if (memory.description) description += `. ${memory.description}`;
    if (memory.generated_caption && !memory.generated_caption.includes('self self')) {
      description += `. The image shows: ${memory.generated_caption}`;
    }
  } else if (memory.type === 'video') {
    description = `Video: "${memory.title}"${peopleText}${timeText}${locationText}`;
    if (memory.description) description += `. ${memory.description}`;
  } else if (memory.type === 'voice') {
    description = `Voice recording: "${memory.title}"${peopleText}${timeText}${locationText}`;
    if (memory.transcription_text) description += `. Transcript: ${memory.transcription_text}`;
  } else if (memory.type === 'text') {
    description = `Note: "${memory.title}"${peopleText}${timeText}${locationText}`;
    if (memory.content) description += `. Content: ${memory.content}`;
  }

  return {
    memory_id: memory.id.toString(),
    type: memory.type,
    description: description.trim(),
  };
}

const enrichAiResponse = async (aiResponse, memoryService) => {
  if (
    aiResponse?.response_type !== 'cinematic_show' ||
    !aiResponse.scenes ||
    aiResponse.scenes.length === 0
  ) {
    return aiResponse;
  }
  const serverIP = getLocalIP();
  const port = process.env.PORT || 3000;
  const aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';

  const enrichmentPromises = aiResponse.scenes.map(async (scene) => {
    const memory = memoryService.findById(scene.memory_id);
    if (!memory) return null;
    const enrichedMemoryDetails = memoryService.generateMemoryURLs(memory, serverIP, port);

    let narrationAudioUrl = null;
    let narrationDurationMs = 5000;

    if (scene.narration && scene.narration.trim()) {
      try {
        const ttsResponse = await axios.post(
          `${aiServiceUrl}/generate-speech`,
          { text: scene.narration },
          { responseType: 'arraybuffer' }
        );
        const durationHeader = ttsResponse.headers['x-audio-duration-ms'];
        if (durationHeader) {
          narrationDurationMs = parseInt(durationHeader, 10);
        }

        const audioFilename = `${randomUUID()}.wav`;
        const audioFilePath = path.join('./tts-cache', audioFilename);
        fs.writeFileSync(audioFilePath, ttsResponse.data);
        narrationAudioUrl = `http://${serverIP}:${port}/tts-cache/${audioFilename}`;
      } catch (ttsError) {
        console.error(
          `❌ Failed to generate TTS for narration of scene ${scene.memory_id}:`,
          ttsError.message
        );
      }
    }

    return {
      ...scene,
      narrationAudioUrl,
      narrationDurationMs,
      memory: {
        id: enrichedMemoryDetails.id,
        type: enrichedMemoryDetails.type,
        title: enrichedMemoryDetails.title,
        contentUrl:
          enrichedMemoryDetails.imageUrl ||
          enrichedMemoryDetails.videoUrl ||
          enrichedMemoryDetails.audioUrl,
      },
    };
  });
  const enrichedScenes = (await Promise.all(enrichmentPromises)).filter(Boolean);
  return { ...aiResponse, scenes: enrichedScenes };
};

async function findRelevantMemoriesByVector(queryText, memoryService, limit = 7) {
  const aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';
  const queryResponse = await axios.post(`${aiServiceUrl}/generate-embedding`, { text: queryText });
  const queryVector = queryResponse.data.vector;

  if (!queryVector) {
    throw new Error('Could not generate vector for query.');
  }

  const allMemoriesWithEmbeddings = memoryService.db
    .prepare('SELECT id, embedding FROM memories WHERE embedding IS NOT NULL')
    .all();

  const scoredMemories = allMemoriesWithEmbeddings.map((mem) => {
    try {
      const memoryVector = JSON.parse(mem.embedding);
      const score = cosineSimilarity(queryVector, memoryVector);
      console.log(`[DEBUG] Memory ID: ${mem.id}, Score: ${score.toFixed(4)}`);
      return { id: mem.id, score };
    } catch (e) {
      return { id: mem.id, score: 0 };
    }
  });

  scoredMemories.sort((a, b) => b.score - a.score);

  const MINIMUM_SIMILARITY = 0.3;
  const relevantMemories = scoredMemories.filter((mem) => mem.score >= MINIMUM_SIMILARITY);
  const topMemoryIds = relevantMemories.slice(0, limit).map((mem) => mem.id);

  if (topMemoryIds.length === 0) {
    return [];
  }

  const memories = topMemoryIds.map((id) => memoryService.findById(id)).filter(Boolean);
  return memories;
}

router.post('/chat', async (req, res) => {
  try {
    const { memoryService, patientService } = req.app.locals;
    const { query, preselected_memory_ids } = req.body;
    if (!query) return res.status(400).json({ success: false, error: 'Query is required.' });

    let relevantMemories = [];
    let contextMemories = [];

    if (preselected_memory_ids && preselected_memory_ids.length > 0) {
      console.log(
        `[/chat] Received pre-selected memory IDs: [${preselected_memory_ids.join(', ')}]. Bypassing vector search.`
      );
      relevantMemories = preselected_memory_ids
        .map((id) => memoryService.findById(id))
        .filter(Boolean);
    } else {
      const casualGreetings = [
        'hello',
        'hi',
        'hey',
        'good morning',
        'good afternoon',
        'good evening',
        'how are you',
      ];
      const isCasualChat = casualGreetings.some(
        (greeting) =>
          query.toLowerCase().trim() === greeting ||
          (query.toLowerCase().includes(greeting) && query.length < 20)
      );
      if (!isCasualChat) {
        console.log('[/chat] No pre-selected IDs. Performing vector search for query.');
        relevantMemories = await findRelevantMemoriesByVector(query, memoryService);
      }
    }

    if (relevantMemories.length > 0) {
      contextMemories = relevantMemories
        .map((mem) => prepareMemoryForAISimple(mem, memoryService))
        .filter(Boolean);
    }

    const patientProfile = await patientService.getCurrentProfile();
    const patientContext = patientProfile ? patientProfile.getAIContext() : null;
    const conversationType = contextMemories.length > 0 ? 'memory_based' : 'casual';

    const aiPayload = {
      query,
      context_memories: contextMemories,
      patient_context: patientContext,
      conversation_type: conversationType,
    };

    const aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';
    const aiResponse = await axios.post(`${aiServiceUrl}/chat`, aiPayload);
    const finalResponse = await enrichAiResponse(aiResponse.data, memoryService);
    res.json(finalResponse);
  } catch (error) {
    console.error('Error in /chat endpoint:', error);
    res.status(500).json({ success: false, error: 'Failed to get AI response.' });
  }
});

router.post('/voice-chat', uploadToMemory.single('voice'), async (req, res) => {
  if (!req.file) return res.status(400).json({ success: false, error: 'No voice file uploaded.' });
  try {
    const { memoryService, patientService } = req.app.locals;
    const aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';
    const formData = new FormData();
    formData.append('audio', req.file.buffer, {
      filename: req.file.originalname,
      contentType: req.file.mimetype,
    });
    const transcriptionResponse = await axios.post(`${aiServiceUrl}/transcribe-audio`, formData, {
      headers: formData.getHeaders(),
    });
    const transcribedText = transcriptionResponse.data.text;

    if (!transcribedText || transcribedText.trim().length === 0) {
      return res.json({
        response_type: 'narrative',
        message: 'I am sorry, I could not hear what you said.',
      });
    }

    const relevantMemories = await findRelevantMemoriesByVector(transcribedText, memoryService);
    let contextMemories = [];
    if (relevantMemories.length > 0) {
      contextMemories = relevantMemories
        .map((mem) => prepareMemoryForAISimple(mem, memoryService))
        .filter(Boolean);
    }

    const patientProfile = await patientService.getCurrentProfile();
    const patientContext = patientProfile ? patientProfile.getAIContext() : null;
    const aiPayload = {
      query: transcribedText,
      context_memories: contextMemories,
      patient_context: patientContext,
      conversation_type: contextMemories.length > 0 ? 'memory_based' : 'casual',
    };

    const aiResponse = await axios.post(`${aiServiceUrl}/chat`, aiPayload);
    const finalResponse = await enrichAiResponse(aiResponse.data, memoryService);
    res.json(finalResponse);
  } catch (error) {
    console.error('Error in /voice-chat endpoint:', error);
    res.status(500).json({ success: false, error: 'Failed to process voice chat.' });
  }
});

router.post('/chat-with-photo', uploadToMemory.single('photo'), async (req, res) => {
  if (!req.file) return res.status(400).json({ success: false, error: 'No photo file uploaded.' });

  const { memoryService, personService, patientService } = req.app.locals;
  const aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';

  try {
    const uploadedPhotoHash = await pHash(req.file.buffer);
    const patientContext = (await patientService.getCurrentProfile())?.getAIContext() || null;
    const matchedMemory = memoryService.findMemoryByPHash(uploadedPhotoHash);

    let query, contextMemories;

    if (matchedMemory) {
      query = `The user showed me a photo I recognize. Please describe the following memory to them in a warm, narrative style. Do not make it a cinematic show.`;
      contextMemories = [prepareMemoryForAISimple(matchedMemory, memoryService)];
    } else {
      const allPeople = await personService.getAllPeople();
      const peopleWithAvatars = allPeople.filter((p) => p.avatar_file);
      const knownFacesPayload = [];

      for (const person of peopleWithAvatars) {
        const avatarFullPath = path.join(__dirname, '../../uploads', person.avatar_file);
        if (fs.existsSync(avatarFullPath)) {
          knownFacesPayload.push({
            person_id: person.id,
            name: person.name,
            avatar_base64: fs.readFileSync(avatarFullPath).toString('base64'),
          });
        }
      }

      const recognitionPayload = {
        photo_to_check_base64: req.file.buffer.toString('base64'),
        known_faces: knownFacesPayload,
      };
      const recognitionResponse = await axios.post(
        `${aiServiceUrl}/recognize-people`,
        recognitionPayload
      );
      const recognizedPeople = recognitionResponse.data.recognized_people;

      if (recognizedPeople && recognizedPeople.length > 0) {
        const names = recognizedPeople.map((p) => p.name).join(', ');
        query = `The user showed me a new photo featuring ${names}. Let's talk about other memories featuring them.`;
        contextMemories = memoryService
          .findRelatedMemoriesForPeople(recognizedPeople.map((p) => p.person_id))
          .map((mem) => prepareMemoryForAISimple(mem, memoryService));
      } else {
        return res.json({
          response_type: 'narrative',
          message:
            "That's a nice photo, but I don't seem to have any information about it. Could you tell me more?",
        });
      }
    }

    const aiPayload = {
      query,
      context_memories: contextMemories,
      patient_context: patientContext,
      conversation_type: 'memory_based',
    };
    const aiResponse = await axios.post(`${aiServiceUrl}/chat`, aiPayload);
    const finalResponse = await enrichAiResponse(aiResponse.data, memoryService);
    res.json(finalResponse);
  } catch (error) {
    console.error('Error in /chat-with-photo endpoint:', error);
    res.status(500).json({ success: false, error: 'Failed to process photo chat.' });
  }
});

router.get('/', async (req, res) => {
  try {
    const memoryService = req.app.locals.memoryService;
    const allMemories = memoryService.getAllMemories();
    const serverIP = getLocalIP();
    const port = process.env.PORT || 3000;
    const memoriesWithUrls = allMemories
      .map((memory) => memoryService.generateMemoryURLs(memory, serverIP, port))
      .filter(Boolean);
    res.json({ success: true, memories: memoriesWithUrls });
  } catch (error) {
    console.error('Error in GET /api/memories:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.get('/:id', async (req, res) => {
  const memoryService = req.app.locals.memoryService;
  const memory = memoryService.findById(req.params.id);
  if (!memory) {
    return res.status(404).json({ success: false, error: 'Memory not found' });
  }
  const serverIP = getLocalIP();
  const port = process.env.PORT || 3000;
  const memoryWithUrls = memoryService.generateMemoryURLs(memory, serverIP, port);
  res.json({ success: true, memory: memoryWithUrls });
});

router.post('/photo', uploadToDisk.single('photo'), async (req, res) => {
  try {
    const memoryService = req.app.locals.memoryService;
    if (!req.file) return res.status(400).json({ success: false, error: 'No photo file uploaded' });
    const dbFilePath = getDbPath(req.file);
    const faceTags = parseJsonField(req.body.faceTags);
    const peopleIds = parseJsonField(req.body.peopleIds);
    const memoryData = {
      title: req.body.title || 'Untitled Photo',
      description: req.body.description || '',
      whenWasThis: req.body.whenWasThis || '',
      whereWasThis: req.body.whereWasThis || '',
      deviceName: req.body.deviceName || 'Unknown Device',
    };
    const perceptualHash = await pHash(req.file.path);
    const memory = await memoryService.createPhotoMemory(
      memoryData,
      dbFilePath,
      faceTags,
      peopleIds,
      perceptualHash
    );
    res.status(201).json({ success: true, memory: memory.toJSON() });
  } catch (error) {
    console.error('❌ Error processing photo upload:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.post('/voice', uploadToDisk.single('voice'), async (req, res) => {
  try {
    const memoryService = req.app.locals.memoryService;
    if (!req.file) return res.status(400).json({ success: false, error: 'No audio file uploaded' });

    const aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';
    const formData = new FormData();
    formData.append('audio', fs.createReadStream(req.file.path));

    const transcriptionResponse = await axios.post(`${aiServiceUrl}/transcribe-audio`, formData, {
      headers: formData.getHeaders(),
    });

    const transcriptionText = transcriptionResponse.data.text;
    const dbFilePath = getDbPath(req.file);
    const peopleIds = parseJsonField(req.body.peopleIds);
    const memoryData = {
      title: req.body.title || 'Untitled Voice Story',
      context: req.body.context || '',
      duration: parseFloat(req.body.duration) || 0,
      deviceName: req.body.deviceName || 'Unknown Device',
    };

    const memory = await memoryService.createVoiceMemory(
      memoryData,
      dbFilePath,
      peopleIds,
      transcriptionText
    );
    res.status(201).json({ success: true, memory: memory.toJSON() });
  } catch (error) {
    console.error(`❌ Error processing voice memory:`, error);
    res
      .status(500)
      .json({ success: false, error: 'Failed to process voice memory.', message: error.message });
  }
});

router.post('/video', uploadToDisk.single('video'), async (req, res) => {
  try {
    const memoryService = req.app.locals.memoryService;
    if (!req.file) return res.status(400).json({ success: false, error: 'No video file uploaded' });
    const dbFilePath = getDbPath(req.file);
    const peopleIds = parseJsonField(req.body.peopleIds);
    const memoryData = {
      title: req.body.title || 'Untitled Video',
      description: req.body.description || '',
      whenWasThis: req.body.whenWasThis || '',
      whereWasThis: req.body.whereWasThis || '',
      deviceName: req.body.deviceName || 'Unknown Device',
      duration: parseFloat(req.body.duration) || 0,
    };
    const memory = await memoryService.createVideoMemory(memoryData, dbFilePath, peopleIds);
    res.status(201).json({ success: true, memory: memory.toJSON() });
  } catch (error) {
    console.error('Error processing video upload:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.post('/text', async (req, res) => {
  try {
    const memoryService = req.app.locals.memoryService;
    const peopleIds = parseJsonField(req.body.peopleIds);
    const memoryData = {
      title: req.body.title || 'Untitled Note',
      content: req.body.content || '',
      description: req.body.description || '',
      whenWasThis: req.body.whenWasThis || '',
      whereWasThis: req.body.whereWasThis || '',
      deviceName: req.body.deviceName || 'Unknown Device',
    };
    const memory = await memoryService.createTextMemory(memoryData, peopleIds);
    res.status(201).json({ success: true, memory: memory.toJSON() });
  } catch (error) {
    console.error('Error processing text memory upload:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

router.put('/:id', async (req, res) => {
  try {
    const memoryService = req.app.locals.memoryService;
    const updatedMemory = await memoryService.updateMemory(req.params.id, req.body);
    res.json({ success: true, memory: updatedMemory.toJSON() });
  } catch (error) {
    console.error(`Error updating memory ${req.params.id}:`, error);
    if (error.message.includes('not found')) {
      return res.status(404).json({ success: false, error: error.message });
    }
    res.status(500).json({ success: false, error: error.message });
  }
});

router.delete('/:id', async (req, res) => {
  try {
    await req.app.locals.memoryService.deleteMemory(req.params.id);
    res.json({ success: true, message: 'Memory deleted' });
  } catch (error) {
    console.error(`Error deleting memory ${req.params.id}:`, error);
    res.status(500).json({ success: false, error: error.message });
  }
});

module.exports = router;