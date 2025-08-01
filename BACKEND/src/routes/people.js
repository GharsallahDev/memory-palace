// src/routes/people.js
const express = require('express');
const router = express.Router();
const { checkAuth } = require('../middleware/authMiddleware');

router.get('/', checkAuth, async (req, res) => {
  try {
    const personService = req.app.locals.personService;
    const people = await personService.getAllPeople();
    res.json({
      success: true,
      people: people,
    });
  } catch (error) {
    console.error(`Error in GET /api/people: ${error.message}`);
    res.status(500).json({
      success: false,
      error: 'Failed to get people due to an internal error.',
      message: error.message,
    });
  }
});

router.get('/:id/memories', checkAuth, (req, res) => {
  try {
    const memoryService = req.app.locals.memoryService;
    const memories = memoryService.getMemoriesForPerson(req.params.id);

    const { getLocalIP } = require('../utils/helpers');
    const serverIP = getLocalIP();
    const port = process.env.PORT || 3000;

    const memoriesWithUrls = memories
      .map((memory) => memoryService.generateMemoryURLs(memory, serverIP, port))
      .filter(Boolean);

    res.json({ success: true, memories: memoriesWithUrls });
  } catch (error) {
    console.error(`Error getting memories for person ${req.params.id}:`, error.message);
    res.status(500).json({ success: false, error: 'Internal Server Error' });
  }
});

router.post('/', checkAuth, async (req, res) => {
  const personService = req.app.locals.personService;
  try {
    const { name, relationship, deviceName } = req.body;

    if (!name || name.trim().length === 0) {
      return res.status(400).json({ success: false, error: 'Person name is required' });
    }

    const person = personService.createPerson({
      name: name.trim(),
      relationship: relationship || null,
      deviceName: deviceName || 'Unknown Device',
    });

    res.status(201).json({
      success: true,
      person: person.toJSON(),
      message: `Person '${person.name}' created successfully`,
    });
  } catch (error) {
    if (error.message.includes('already exists')) {
      res.status(409).json({ success: false, error: error.message });
    } else {
      res.status(500).json({ success: false, error: error.message });
    }
  }
});

router.put('/:id', checkAuth, (req, res) => {
  const personService = req.app.locals.personService;
  try {
    const { name, relationship } = req.body;
    const person = personService.updatePerson(req.params.id, { name, relationship });
    res.json({
      success: true,
      person: person.toJSON(),
      message: `Person '${person.name}' updated successfully`,
    });
  } catch (error) {
    if (error.message.includes('not found')) {
      res.status(404).json({ success: false, error: error.message });
    } else {
      res.status(500).json({ success: false, error: error.message });
    }
  }
});

router.delete('/:id', checkAuth, (req, res) => {
  const personService = req.app.locals.personService;
  try {
    personService.deletePerson(req.params.id);
    res.json({ success: true, message: 'Person deleted successfully' });
  } catch (error) {
    if (error.message.includes('not found')) {
      res.status(404).json({ success: false, error: error.message });
    } else {
      res.status(500).json({ success: false, error: error.message });
    }
  }
});

router.get('/:id', checkAuth, (req, res) => {
  const personService = req.app.locals.personService;
  try {
    const person = personService.findById(req.params.id);

    if (!person) {
      return res.status(404).json({
        success: false,
        error: 'Person not found',
      });
    }

    const enrichedPerson = req.app.locals.personService._enrichPerson(person);

    res.json({
      success: true,
      person: enrichedPerson,
    });
  } catch (error) {
    console.error('❌ Error fetching person:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

module.exports = router;