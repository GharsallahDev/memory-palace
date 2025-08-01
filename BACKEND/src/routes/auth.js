// src/routes/auth.js
const express = require('express');
const router = express.Router();
const { checkAuth, optionalAuth, createRateLimiter } = require('../middleware/authMiddleware');

router.get('/status', optionalAuth, (req, res) => {
  try {
    res.json({
      success: true,
      authenticated: req.user.authenticated,
      serverTime: new Date().toISOString(),
      sessionInfo: req.user.authenticated
        ? {
            tokenPrefix: req.user.tokenUsed,
            authenticatedAt: req.user.timestamp,
          }
        : null,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

router.post('/validate', (req, res) => {
  try {
    const { token } = req.body;
    if (!token) {
      return res.status(400).json({
        success: false,
        error: 'Token is required',
      });
    }

    const validToken = req.app.locals.AUTH_TOKEN;
    const isValid = token === validToken;

    res.json({
      success: true,
      valid: isValid,
    });
  } catch (error) {
    console.error('❌ Error validating token:', error.message);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

router.get('/info', (req, res) => {
  try {
    res.json({
      success: true,
      authRequired: true,
      method: 'Bearer token',
      headerName: 'x-auth-token',
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});

const authRateLimit = createRateLimiter(15 * 60 * 1000, 20);
router.use(authRateLimit);

router.use((error, req, res, next) => {
  console.error('❌ Auth route error:', error);
  res.status(500).json({
    success: false,
    error: 'Authentication service error',
  });
});

module.exports = router;