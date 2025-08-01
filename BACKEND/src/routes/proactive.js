// src/routes/proactive.js
const express = require('express');
const router = express.Router();
const { checkAuth } = require('../middleware/authMiddleware');

router.get('/check', checkAuth, async (req, res) => {
  try {
    const { proactiveTriggerService, webSocketService } = req.app.locals;
    const trigger = await proactiveTriggerService.checkAllTriggers();

    if (!trigger) {
      return res.json({
        success: true,
        trigger: null,
        message: 'No proactive triggers found at this time',
      });
    }

    const alreadyViewed = proactiveTriggerService.wasAlreadyViewedToday(
      trigger.trigger_type,
      trigger.trigger_date
    );

    if (alreadyViewed) {
      return res.json({
        success: true,
        trigger: trigger,
        already_viewed: true,
        message: 'This trigger was already viewed today',
      });
    }

    const pendingTrigger = proactiveTriggerService.getPendingTriggerToday(
      trigger.trigger_type,
      trigger.trigger_date
    );

    if (pendingTrigger) {
      return res.json({
        success: true,
        trigger: trigger,
        already_delivered: true,
        message: 'This trigger was already delivered but not yet viewed',
      });
    }

    const delivered = webSocketService.sendProactiveMemory(trigger, 'patient');
    proactiveTriggerService.saveProactiveMemory(trigger, delivered);

    res.json({
      success: true,
      trigger: trigger,
      delivered: delivered,
      message: delivered
        ? 'Proactive memory sent successfully'
        : 'Proactive memory queued for delivery',
    });
  } catch (error) {
    console.error('❌ Error in proactive check:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to check proactive triggers',
      message: error.message,
    });
  }
});

router.get('/triggers', checkAuth, async (req, res) => {
  try {
    const { proactiveTriggerService } = req.app.locals;

    const onThisDay = proactiveTriggerService.checkOnThisDay();
    const anniversaries = proactiveTriggerService.checkAnniversaries();
    const seasonal = proactiveTriggerService.checkSeasonal();

    res.json({
      success: true,
      triggers: {
        on_this_day: onThisDay,
        anniversaries: anniversaries,
        seasonal: seasonal,
      },
      summary: {
        total_triggers: [onThisDay, anniversaries, seasonal].filter(Boolean).length,
        has_triggers: !!(onThisDay || anniversaries || seasonal),
      },
    });
  } catch (error) {
    console.error('❌ Error getting triggers:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to get triggers',
      message: error.message,
    });
  }
});

router.post('/send', checkAuth, async (req, res) => {
  try {
    const { webSocketService, proactiveTriggerService } = req.app.locals;
    const trigger = req.body;

    if (!trigger || !trigger.trigger_type || !trigger.memories) {
      return res.status(400).json({
        success: false,
        error: 'A valid, pre-built trigger object is required in the request body.',
      });
    }

    console.log(
      `[Proactive API] Received trigger '${trigger.trigger_type}' from worker. Preparing to send via WebSocket.`
    );
    const delivered = webSocketService.sendProactiveMemory(trigger, 'patient');
    proactiveTriggerService.saveProactiveMemory(trigger, delivered);
    console.log(
      `[Proactive API] WebSocket delivery status: ${delivered ? 'DELIVERED to at least one client.' : 'QUEUED as no clients are connected.'}`
    );

    res.json({
      success: true,
      trigger: trigger,
      delivered: delivered,
      message: 'Proactive memory sent successfully',
    });
  } catch (error) {
    console.error('❌ Error sending proactive memory:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to send proactive memory',
      message: error.message,
    });
  }
});

router.post('/view/:id', checkAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const { proactiveTriggerService } = req.app.locals;
    proactiveTriggerService.markAsViewed(id);
    res.json({
      success: true,
      message: 'Proactive memory marked as viewed',
      proactive_id: id,
      action: 'viewed',
    });
  } catch (error) {
    console.error('❌ Error marking proactive memory as viewed:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to mark proactive memory as viewed',
      message: error.message,
    });
  }
});

router.post('/dismiss/:id', checkAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const { proactiveTriggerService } = req.app.locals;
    proactiveTriggerService.markAsDismissed(id);
    res.json({
      success: true,
      message: 'Proactive memory marked as dismissed',
      proactive_id: id,
      action: 'dismissed',
    });
  } catch (error) {
    console.error('❌ Error marking proactive memory as dismissed:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to mark proactive memory as dismissed',
      message: error.message,
    });
  }
});

router.get('/history', checkAuth, async (req, res) => {
  try {
    const { databaseService } = req.app.locals;
    const db = databaseService.getDb();

    const history = db
      .prepare(
        `
      SELECT * FROM proactive_memories
      ORDER BY created_at DESC
      LIMIT 50
    `
      )
      .all();

    const enrichedHistory = history.map((record) => {
      const memoryIds = JSON.parse(record.memory_ids || '[]');
      let status = 'pending';
      if (record.viewed_at) {
        status = 'viewed';
      } else if (record.dismissed_at) {
        status = 'dismissed';
      } else if (record.delivered_at) {
        status = 'delivered';
      }
      return { ...record, memory_ids: memoryIds, memory_count: memoryIds.length, status };
    });

    res.json({
      success: true,
      history: enrichedHistory,
      total: history.length,
    });
  } catch (error) {
    console.error('❌ Error getting proactive history:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to get proactive history',
      message: error.message,
    });
  }
});

router.get('/stats', checkAuth, async (req, res) => {
  try {
    const { databaseService, webSocketService } = req.app.locals;
    const db = databaseService.getDb();

    const engagementStats = db
      .prepare(
        `
      SELECT
        trigger_type,
        COUNT(*) as total_sent,
        COUNT(CASE WHEN delivered_at IS NOT NULL THEN 1 END) as delivered,
        COUNT(CASE WHEN viewed_at IS NOT NULL THEN 1 END) as viewed,
        COUNT(CASE WHEN dismissed_at IS NOT NULL THEN 1 END) as dismissed,
        COUNT(CASE WHEN delivered_at IS NOT NULL AND viewed_at IS NULL AND dismissed_at IS NULL THEN 1 END) as pending
      FROM proactive_memories
      GROUP BY trigger_type
    `
      )
      .all();

    const todayActivity = db
      .prepare(
        `
      SELECT
        COUNT(*) as total,
        COUNT(CASE WHEN viewed_at IS NOT NULL THEN 1 END) as viewed,
        COUNT(CASE WHEN dismissed_at IS NOT NULL THEN 1 END) as dismissed
      FROM proactive_memories
      WHERE DATE(created_at) = DATE('now')
    `
      )
      .get();

    const wsStats = webSocketService.getStats();

    res.json({
      success: true,
      stats: {
        engagement_by_type: engagementStats,
        today: todayActivity,
        websocket: wsStats,
        summary: {
          total_delivered: engagementStats.reduce((sum, stat) => sum + stat.delivered, 0),
          total_viewed: engagementStats.reduce((sum, stat) => sum + stat.viewed, 0),
          total_dismissed: engagementStats.reduce((sum, stat) => sum + stat.dismissed, 0),
          total_pending: engagementStats.reduce((sum, stat) => sum + stat.pending, 0),
          engagement_rate:
            engagementStats.reduce((sum, stat) => sum + stat.delivered, 0) > 0
              ? (
                  (engagementStats.reduce((sum, stat) => sum + stat.viewed, 0) /
                    engagementStats.reduce((sum, stat) => sum + stat.delivered, 0)) *
                  100
                ).toFixed(1)
              : 0,
        },
      },
    });
  } catch (error) {
    console.error('❌ Error getting proactive stats:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to get proactive stats',
      message: error.message,
    });
  }
});

router.post('/test', checkAuth, async (req, res) => {
  try {
    const { webSocketService } = req.app.locals;
    const testMemory = {
      trigger_type: 'test',
      trigger_date: new Date().toISOString().split('T')[0],
      title: 'Test Proactive Memory',
      description: 'This is a test proactive memory to verify WebSocket delivery',
      memories: [{ id: 'test_1', type: 'test', title: 'Test Memory' }],
    };
    const delivered = webSocketService.sendProactiveMemory(testMemory, 'patient');
    res.json({
      success: true,
      delivered: delivered,
      connected_clients: webSocketService.getStats().totalConnections,
      message: delivered
        ? 'Test memory sent successfully'
        : 'Test memory queued (no connected clients)',
    });
  } catch (error) {
    console.error('❌ Error sending test proactive memory:', error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to send test proactive memory',
      message: error.message,
    });
  }
});

module.exports = router;