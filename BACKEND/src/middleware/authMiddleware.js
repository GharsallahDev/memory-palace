// src/middleware/authMiddleware.js

function checkAuth(req, res, next) {
  const token = req.headers['x-auth-token'];
  const validToken = req.app.locals.AUTH_TOKEN;

  if (token && token === validToken) {
    req.user = {
      authenticated: true,
      tokenUsed: token.substring(0, 8) + '...',
      timestamp: new Date().toISOString(),
    };
    next();
  } else {
    console.warn(`[AUTH] Authentication failed: Invalid token from ${req.ip}`);
    res.status(401).json({
      success: false,
      error: 'Authentication required',
      message: 'Invalid or missing authentication token.',
      requiredHeader: 'x-auth-token',
    });
  }
}

function optionalAuth(req, res, next) {
  const token = req.headers['x-auth-token'] || req.body.authToken || req.query.authToken;
  const validToken = req.app.locals.AUTH_TOKEN;

  if (token && token === validToken) {
    req.user = {
      authenticated: true,
      tokenUsed: token.substring(0, 8) + '...',
      timestamp: new Date().toISOString(),
    };
  } else {
    req.user = {
      authenticated: false,
      timestamp: new Date().toISOString(),
    };
  }
  next();
}

function createRateLimiter(windowMs = 15 * 60 * 1000, max = 100) {
  const requests = new Map();

  return (req, res, next) => {
    const ip = req.ip;
    const now = Date.now();

    for (const [key, value] of requests.entries()) {
      if (now - value.firstRequest > windowMs) {
        requests.delete(key);
      }
    }

    if (!requests.has(ip)) {
      requests.set(ip, { count: 1, firstRequest: now });
      return next();
    }

    const requestInfo = requests.get(ip);
    requestInfo.count++;

    if (requestInfo.count > max) {
      return res.status(429).json({
        success: false,
        error: 'Too many requests',
        message: `Rate limit exceeded. Max ${max} requests per ${windowMs / 1000} seconds.`,
        retryAfter: Math.ceil((windowMs - (now - requestInfo.firstRequest)) / 1000),
      });
    }
    next();
  };
}

module.exports = {
  checkAuth,
  optionalAuth,
  createRateLimiter,
};