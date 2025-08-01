// src/routes/tts.js
const express = require('express');
const router = express.Router();
const axios = require('axios');

/**
 * @route   POST /api/tts
 * @desc    Generate speech from text on-demand.
 * @access  Protected
 */
router.post('/', async (req, res) => {
  const { text } = req.body;

  if (!text || typeof text !== 'string' || text.trim().length === 0) {
    return res
      .status(400)
      .json({ success: false, error: 'Text field is required and cannot be empty.' });
  }

  try {
    const aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';
    const ttsResponse = await axios.post(
      `${aiServiceUrl}/generate-speech`,
      { text },
      { responseType: 'stream' }
    );

    res.set('Content-Type', 'audio/wav');
    ttsResponse.data.pipe(res);
  } catch (error) {
    console.error('❌ TTS route error:', error.message);

    if (error.response) {
      const status = error.response.status || 500;
      console.error('Underlying AI Service Error Status:', status);
      res.status(status).json({
        success: false,
        error: 'Failed to generate speech from AI service.',
        details: 'The AI service returned an error. Check server logs for more information.',
      });
    } else {
      res.status(500).json({
        success: false,
        error: 'Internal Server Error while generating speech.',
      });
    }
  }
});

module.exports = router;