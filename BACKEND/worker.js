// worker.js
const cron = require('node-cron');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const FormData = require('form-data');
const sharp = require('sharp');
require('dotenv').config();

const dbService = require('./src/services/DatabaseService');
const PersonService = require('./src/services/PersonService');
const MemoryService = require('./src/services/MemoryService');
const FileService = require('./src/services/FileService');
const ProactiveTriggerService = require('./src/services/ProactiveTriggerService');

const db = dbService.getDb();

const AI_SERVICE_URL = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';
const BACKEND_URL = process.env.BACKEND_URL || 'http://127.0.0.1:3000';
const AUTH_TOKEN = process.env.AUTH_TOKEN;
const UPLOADS_DIR = path.join(__dirname, 'uploads');
const AVATARS_DIR = path.join(UPLOADS_DIR, 'avatars');
const MAX_ATTEMPTS = 3;

if (!AUTH_TOKEN) {
  console.error('❌ WORKER FATAL ERROR: AUTH_TOKEN is not defined.');
  process.exit(1);
}

const personService = new PersonService();
const fileService = new FileService();
const memoryService = new MemoryService(personService, fileService);
const proactiveTriggerService = new ProactiveTriggerService(memoryService);

async function handleCaptionJob(job) {
  const memory = db.prepare('SELECT image_file FROM memories WHERE id = ?').get(job.memory_id);
  if (!memory || !memory.image_file) {
    throw new Error(`Memory or image_file not found for memory_id: ${job.memory_id}`);
  }
  const filePath = path.join(UPLOADS_DIR, memory.image_file);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Image file does not exist: ${filePath}`);
  }

  const formData = new FormData();
  formData.append('image', fs.createReadStream(filePath));

  const response = await axios.post(`${AI_SERVICE_URL}/describe-image`, formData, {
    headers: formData.getHeaders(),
  });

  const { caption } = response.data;
  if (!caption) {
    throw new Error('Vision service returned an empty caption.');
  }

  db.prepare('UPDATE memories SET generated_caption = ? WHERE id = ?').run(caption, job.memory_id);
}

async function processAvatarQueue() {
  console.log('[Avatar Worker] --- Checking for people needing new avatars ---');
  const peopleToProcess = db
    .prepare(
      `
    SELECT p.id, p.avatar_file, p.avatar_source_memory_id
    FROM people p
    LEFT JOIN memories m ON p.avatar_source_memory_id = m.id
    WHERE p.avatar_source_memory_id IS NULL OR m.id IS NULL
  `
    )
    .all();

  if (peopleToProcess.length === 0) {
    console.log('[Avatar Worker] All person avatars are up-to-date.');
    return;
  }
  console.log(
    `[Avatar Worker] Found ${peopleToProcess.length} people requiring avatar processing.`
  );

  for (const person of peopleToProcess) {
    try {
      console.log(`[Avatar Worker] ↳ Processing Person ID: ${person.id}`);
      const nextAvatarSource = db
        .prepare(
          `
        SELECT m.id as memory_id, m.image_file, ft.bounding_box
        FROM face_tags ft
        JOIN memories m ON ft.memory_id = m.id
        WHERE ft.person_id = ? AND m.type = 'photo' AND m.image_file IS NOT NULL
        ORDER BY m.timestamp ASC
        LIMIT 1
      `
        )
        .get(person.id);

      if (!nextAvatarSource) {
        console.log(
          `[Avatar Worker]   - No suitable photo memory found for Person ID: ${person.id}. Clearing avatar.`
        );
        if (person.avatar_file) {
          const oldAvatarPath = path.join(UPLOADS_DIR, person.avatar_file);
          if (fs.existsSync(oldAvatarPath)) {
            fs.unlinkSync(oldAvatarPath);
          }
        }
        db.prepare(
          'UPDATE people SET avatar_file = NULL, avatar_source_memory_id = NULL WHERE id = ?'
        ).run(person.id);
        continue;
      }

      const { memory_id, image_file, bounding_box } = nextAvatarSource;
      console.log(
        `[Avatar Worker]   - Found new avatar source in Memory ID: ${memory_id} (File: ${image_file})`
      );
      const sourceImagePath = path.join(UPLOADS_DIR, image_file);

      if (!fs.existsSync(sourceImagePath)) {
        console.error(
          `Avatar Worker: Source image ${sourceImagePath} not found for person ${person.id}.`
        );
        continue;
      }

      const bbox = JSON.parse(bounding_box);
      const image = sharp(sourceImagePath);
      const metadata = await image.metadata();

      const PADDING_FACTOR = 0.3;
      const left = Math.floor(metadata.width * bbox.x);
      const top = Math.floor(metadata.height * bbox.y);
      const width = Math.ceil(metadata.width * bbox.width);
      const height = Math.ceil(metadata.height * bbox.height);

      const paddedWidth = Math.floor(width * (1 + PADDING_FACTOR));
      const paddedHeight = Math.floor(height * (1 + PADDING_FACTOR));
      const paddedLeft = Math.max(0, left - Math.floor((paddedWidth - width) / 2));
      const paddedTop = Math.max(0, top - Math.floor((paddedHeight - height) / 2));

      const avatarFileName = `person_${person.id}_${Date.now()}.jpg`;
      const avatarFilePath = path.join(AVATARS_DIR, avatarFileName);
      const avatarDbPath = `avatars/${avatarFileName}`;

      await image
        .extract({
          left: paddedLeft,
          top: paddedTop,
          width: Math.min(paddedWidth, metadata.width - paddedLeft),
          height: Math.min(paddedHeight, metadata.height - paddedTop),
        })
        .resize(200, 200)
        .toFormat('jpeg')
        .toFile(avatarFilePath);

      console.log(`[Avatar Worker]   ✓ Successfully created and saved new avatar: ${avatarDbPath}`);
      db.prepare('UPDATE people SET avatar_file = ?, avatar_source_memory_id = ? WHERE id = ?').run(
        avatarDbPath,
        memory_id,
        person.id
      );
    } catch (error) {
      console.error(`❌ Avatar Worker: Failed to process avatar for person ${person.id}:`, error);
    }
  }
}

async function checkAndSendProactiveMemories() {
  try {
    console.log('[Proactive Worker] --- Checking all proactive memory triggers ---');
    const trigger = await proactiveTriggerService.checkAllTriggers();
    if (!trigger) {
      console.log('[Proactive Worker] No proactive triggers found at this time.');
      return;
    }

    console.log('----------------------------------------------------');
    console.log(`[Proactive Worker] ✓ TRIGGER FOUND AND SELECTED`);
    console.log(`  - Type: ${trigger.trigger_type}`);
    console.log(`  - Title: ${trigger.title}`);
    console.log(
      `  - Memories (${trigger.memories.length}): ${trigger.memories.map((m) => m.id).join(', ')}`
    );
    console.log('----------------------------------------------------');

    const alreadyViewed = proactiveTriggerService.wasAlreadyViewedToday(
      trigger.trigger_type,
      trigger.trigger_date
    );
    if (alreadyViewed) {
      console.log(
        `[Proactive Worker] - Trigger '${trigger.trigger_type}' was already viewed today. Skipping.`
      );
      return;
    }

    console.log(`[Proactive Worker] → Sending trigger to main app for delivery...`);
    await sendTriggerViaAPI(trigger);
  } catch (error) {
    console.error('❌ Proactive Worker: Error checking triggers:', error.message);
  }
}

async function sendTriggerViaAPI(trigger) {
  try {
    await axios.post(`${BACKEND_URL}/api/proactive/send`, JSON.stringify(trigger), {
      headers: {
        'x-auth-token': AUTH_TOKEN,
        'Content-Type': 'application/json',
      },
    });
  } catch (error) {
    if (error.code === 'ECONNREFUSED') {
      console.error('❌ Proactive Worker: Cannot connect to main app. Is it running?');
    } else if (error.response) {
      console.error(
        `❌ Proactive Worker: API error ${error.response.status} - ${error.response.data?.error || error.message}`
      );
    } else {
      console.error('❌ Proactive Worker: Network error:', error.message);
    }
  }
}

function cleanupOldProactiveMemories() {
  try {
    console.log('[Cleanup Worker] --- Cleaning up old proactive memories ---');
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const result = db
      .prepare(`DELETE FROM proactive_memories WHERE created_at < ?`)
      .run(thirtyDaysAgo.toISOString());
    if (result.changes > 0) {
      console.log(`[Cleanup Worker] ✓ Deleted ${result.changes} old proactive records.`);
    } else {
      console.log('[Cleanup Worker] No old records to delete.');
    }
  } catch (error) {
    console.error('❌ Proactive Worker: Cleanup error:', error.message);
  }
}

async function mainWorkerLoop() {
  await processAvatarQueue();

  const job = db.transaction(() => {
    const jobData = db
      .prepare(
        "SELECT * FROM ai_generation_queue WHERE status = 'pending' AND attempts < ? ORDER BY created_at ASC LIMIT 1"
      )
      .get(MAX_ATTEMPTS);
    if (jobData) {
      db.prepare(
        "UPDATE ai_generation_queue SET status = 'processing', attempts = attempts + 1 WHERE id = ?"
      ).run(jobData.id);
    }
    return jobData;
  })();

  if (!job) {
    return;
  }

  try {
    if (job.task_type === 'caption') {
      await handleCaptionJob(job);
    } else {
      throw new Error(`Unknown job task_type: ${job.task_type}`);
    }

    db.prepare(
      "UPDATE ai_generation_queue SET status = 'completed', processed_at = strftime('%Y-%m-%d %H:%M:%f', 'now') WHERE id = ?"
    ).run(job.id);
  } catch (error) {
    const errorMessage = error.response ? JSON.stringify(error.response.data) : error.message;
    console.error(`❌ AI Worker: Failed to process job ${job.id}:`, errorMessage);
    db.prepare(
      "UPDATE ai_generation_queue SET status = 'failed', error_message = ? WHERE id = ?"
    ).run(errorMessage, job.id);
  }
}

cron.schedule('*/5 * * * *', mainWorkerLoop);
cron.schedule('*/5 * * * *', checkAndSendProactiveMemories);
cron.schedule('*/5 * * * *', cleanupOldProactiveMemories);

process.on('SIGINT', () => {
  console.log('📴 Shutting down Worker...');
  dbService.close();
  process.exit(0);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception in Worker:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection in Worker:', promise, 'reason:', reason);
  process.exit(1);
});

console.log('🚀 Background Worker Started');
console.log('🚀 Performing initial run of all scheduled tasks...');

mainWorkerLoop();
checkAndSendProactiveMemories();
cleanupOldProactiveMemories();

console.log('🚀 Initial run complete. Worker now running on a 1-minute schedule for all tasks.');