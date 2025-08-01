// src/services/ProactiveAnalysisService.js
const axios = require('axios');

class ProactiveAnalysisService {
  constructor() {
    this.aiServiceUrl = process.env.PYTHON_SERVICE_URL || 'http://127.0.0.1:5000';
  }

  /**
   * Analyzes a memory using the dedicated analysis endpoint
   * @param {Object} memory - Memory object to analyze
   * @returns {Object} Analysis result with anniversary_type, seasonal_tags, proactive_score
   */
  async analyzeMemory(memory) {
    try {
      const peopleNames = memory.getPeopleNames ? memory.getPeopleNames() : [];

      const analysisPayload = {
        title: memory.title || 'Untitled Memory',
        description: memory.description || '',
        type: memory.type || 'unknown',
        date: memory.whenWasThis || memory.timestamp || null,
        location: memory.whereWasThis || null,
        people_present: peopleNames.length > 0 ? peopleNames : null,
      };

      const response = await axios.post(`${this.aiServiceUrl}/analyze-memory`, analysisPayload, {
        headers: { 'Content-Type': 'application/json' },
      });

      const result = response.data;

      return {
        anniversary_type: result.anniversary_type,
        seasonal_tags: result.seasonal_tags || [],
        proactive_score: result.proactive_score || 0,
      };
    } catch (error) {
      console.error(`❌ Failed to analyze memory ${memory.id}:`, error.message);
      return {
        anniversary_type: null,
        seasonal_tags: [],
        proactive_score: 0,
      };
    }
  }
}

module.exports = ProactiveAnalysisService;