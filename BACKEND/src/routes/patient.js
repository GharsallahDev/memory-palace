// src/routes/patient.js
const express = require('express');
const multer = require('multer');
const router = express.Router();
const { checkAuth } = require('../middleware/authMiddleware');

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, './uploads');
  },
  filename: (req, file, cb) => {
    const timestamp = Date.now();
    const sanitizedName = file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
    cb(null, `patient-${timestamp}-${sanitizedName}`);
  },
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed for patient photos'), false);
    }
  },
});

router.get('/profile', checkAuth, async (req, res) => {
  try {
    const patientService = req.app.locals.patientService;
    let profile = await patientService.getCurrentProfile();

    if (!profile) {
      const defaultProfile = {
        id: null,
        name: '',
        photoFile: null,
        photoUrl: null,
        description: '',
        birthDate: null,
        createdAt: null,
        updatedAt: null,
      };
      return res.json({
        success: true,
        profile: defaultProfile,
      });
    }

    const { getLocalIP } = require('../utils/helpers');
    const serverIP = getLocalIP();
    const port = process.env.PORT || 3000;
    const profileData = profile.toJSON();

    if (profileData.photoFile) {
      profileData.photoUrl = `http://${serverIP}:${port}/uploads/${profileData.photoFile}`;
    }

    res.json({
      success: true,
      profile: profileData,
    });
  } catch (error) {
    console.error('❌ Error getting patient profile:', error.message);
    res
      .status(500)
      .json({ success: false, error: 'Internal Server Error', message: error.message });
  }
});

router.post('/profile', checkAuth, upload.single('photo'), async (req, res) => {
  try {
    const patientService = req.app.locals.patientService;
    const { name, description, birthDate } = req.body;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({ success: false, error: 'Patient name is required' });
    }

    const currentProfile = await patientService.getCurrentProfile();

    const profileData = {
      name: name.trim(),
      description: description?.trim() || '',
      birthDate: birthDate || null,
      photoFile: req.file ? req.file.filename : currentProfile?.photoFile || null,
    };

    const profile = await patientService.createOrUpdateProfile(profileData);

    const { getLocalIP } = require('../utils/helpers');
    const serverIP = getLocalIP();
    const port = process.env.PORT || 3000;
    const profileResponse = profile.toJSON();

    if (profileResponse.photoFile) {
      profileResponse.photoUrl = `http://${serverIP}:${port}/uploads/${profileResponse.photoFile}`;
    }

    res.status(200).json({
      success: true,
      profile: profileResponse,
      message: `Patient profile for ${profile.name} saved successfully`,
    });
  } catch (error) {
    console.error('❌ Error saving patient profile:', error.message);
    res
      .status(500)
      .json({ success: false, error: 'Internal Server Error', message: error.message });
  }
});

router.delete('/profile', checkAuth, async (req, res) => {
  try {
    const patientService = req.app.locals.patientService;
    await patientService.deleteProfile();

    res.json({
      success: true,
      message: 'Patient profile deleted successfully',
    });
  } catch (error) {
    console.error('❌ Error deleting patient profile:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

router.get('/context', checkAuth, async (req, res) => {
  try {
    const patientService = req.app.locals.patientService;
    const context = patientService.getPatientContext();

    res.json({
      success: true,
      context: context,
      aiPrompt: patientService.generateAIContext(),
    });
  } catch (error) {
    console.error('❌ Error getting patient context:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

router.get('/memories', checkAuth, async (req, res) => {
  try {
    const patientService = req.app.locals.patientService;
    const memories = await patientService.getPatientMemories();

    res.json({
      success: true,
      memories: memories,
      total: memories.length,
    });
  } catch (error) {
    console.error('❌ Error getting patient memories:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

router.get('/stats', checkAuth, async (req, res) => {
  try {
    const patientService = req.app.locals.patientService;
    const stats = await patientService.getStats();

    res.json({
      success: true,
      stats: stats,
    });
  } catch (error) {
    console.error('❌ Error getting patient stats:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

router.post('/analyze-memory/:id', checkAuth, async (req, res) => {
  try {
    const patientService = req.app.locals.patientService;
    const memoryService = req.app.locals.memoryService;

    const memory = await memoryService.findById(req.params.id);
    if (!memory) {
      return res.status(404).json({
        success: false,
        error: 'Memory not found',
      });
    }

    const analysis = await patientService.analyzeMemoryForPatient(memory);

    res.json({
      success: true,
      analysis: analysis,
      message: 'Memory analyzed for patient presence',
    });
  } catch (error) {
    console.error('❌ Error analyzing memory:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

module.exports = router;