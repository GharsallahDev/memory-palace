// src/services/ProactiveTriggerService.js
const dbService = require('./DatabaseService');

class ProactiveTriggerService {
  constructor(memoryService) {
    this.db = dbService.getDb();
    this.memoryService = memoryService;
  }

  checkOnThisDay() {
    try {
      const today = new Date();
      const todayMD = this._formatMonthDay(today);
      const currentYear = today.getFullYear().toString();

      const memories = this.db
        .prepare(
          `
        SELECT * FROM memories
        WHERE
          when_was_this IS NOT NULL AND when_was_this != ''
          AND strftime('%m-%d', when_was_this) = ?
          AND strftime('%Y', when_was_this) != ?
          AND proactive_score >= 1
        ORDER BY proactive_score DESC, timestamp DESC
        LIMIT 5
      `
        )
        .all(todayMD, currentYear);

      console.log(
        `[Proactive Service | On This Day] DB query found ${memories.length} potential memories.`
      );
      if (memories.length > 0) {
        const debugInfo = memories.map((m) => ({
          id: m.id,
          when_was_this: m.when_was_this,
          title: m.title,
        }));
        console.log(
          `[Proactive Service | On This Day] Retrieved Memories:`,
          JSON.stringify(debugInfo, null, 2)
        );
      }

      const enrichedMemories = memories
        .map((row) => this.memoryService._enrichMemoryWithTags(row))
        .filter(Boolean);

      if (enrichedMemories.length > 0) {
        return {
          trigger_type: 'on_this_day',
          trigger_date: today.toISOString().split('T')[0],
          memories: enrichedMemories,
          title: this._generateOnThisDayTitle(enrichedMemories),
          description: `Memories from this day in previous years`,
        };
      }
      return null;
    } catch (error) {
      console.error('❌ Error checking "On This Day" memories:', error.message);
      return null;
    }
  }

  checkAnniversaries() {
    try {
      const today = new Date();
      const todayMD = this._formatMonthDay(today);
      const currentYear = today.getFullYear().toString();

      const memories = this.db
        .prepare(
          `
        SELECT * FROM memories
        WHERE
          anniversary_type IS NOT NULL
          AND when_was_this IS NOT NULL AND when_was_this != ''
          AND strftime('%m-%d', when_was_this) = ?
          AND strftime('%Y', when_was_this) != ?
        ORDER BY proactive_score DESC, timestamp DESC
        LIMIT 3
      `
        )
        .all(todayMD, currentYear);

      console.log(
        `[Proactive Service | Anniversary] DB query found ${memories.length} potential memories.`
      );
      if (memories.length > 0) {
        const debugInfo = memories.map((m) => ({
          id: m.id,
          when_was_this: m.when_was_this,
          title: m.title,
          anniversary: m.anniversary_type,
        }));
        console.log(
          `[Proactive Service | Anniversary] Retrieved Memories:`,
          JSON.stringify(debugInfo, null, 2)
        );
      }

      const enrichedMemories = memories
        .map((row) => this.memoryService._enrichMemoryWithTags(row))
        .filter(Boolean);

      if (enrichedMemories.length > 0) {
        return {
          trigger_type: 'anniversary',
          trigger_date: today.toISOString().split('T')[0],
          memories: enrichedMemories,
          title: this._generateAnniversaryTitle(enrichedMemories),
          description: `Special anniversaries from today`,
        };
      }
      return null;
    } catch (error) {
      console.error('❌ Error checking anniversary memories:', error.message);
      return null;
    }
  }

  checkSeasonal() {
    try {
      const currentMonth = new Date().getMonth() + 1;
      const currentSeason = this._getCurrentSeason(currentMonth);

      const memories = this.db
        .prepare(
          `
        SELECT * FROM memories
        WHERE seasonal_tags IS NOT NULL
        AND proactive_score >= 2
        ORDER BY proactive_score DESC, timestamp DESC
        LIMIT 10
      `
        )
        .all();

      console.log(
        `[Proactive Service | Seasonal] DB query found ${memories.length} total memories with seasonal tags.`
      );

      const seasonalMemories = memories
        .map((row) => this.memoryService._enrichMemoryWithTags(row))
        .filter((memory) => {
          if (!memory || !memory.seasonal_tags) return false;
          try {
            const tags = JSON.parse(memory.seasonal_tags);
            return this._isSeasonallyRelevant(tags, currentMonth);
          } catch (e) {
            return false;
          }
        })
        .slice(0, 3);

      if (seasonalMemories.length > 0) {
        console.log(
          `[Proactive Service | Seasonal] Filtered down to ${seasonalMemories.length} relevant memories for this month.`
        );
      }

      if (seasonalMemories.length > 0) {
        return {
          trigger_type: 'seasonal',
          trigger_date: new Date().toISOString().split('T')[0],
          memories: seasonalMemories,
          title: this._generateSeasonalTitle(seasonalMemories, currentSeason),
          description: `Memories perfect for this time of year`,
        };
      }
      return null;
    } catch (error) {
      console.error('❌ Error checking seasonal memories:', error.message);
      return null;
    }
  }

  async checkAllTriggers() {
    const triggers = [
      this.checkAnniversaries(),
      this.checkOnThisDay(),
      this.checkSeasonal(),
    ].filter(Boolean);

    if (triggers.length === 0) {
      return null;
    }

    const bestTrigger = triggers[0];

    try {
      const directorResponse = await this._buildCinematicExperience(bestTrigger);
      bestTrigger.director_response = directorResponse;
    } catch (error) {
      console.error(`❌ Failed to build cinematic experience: ${error.message}`);
      bestTrigger.director_response = null;
    }

    return bestTrigger;
  }

  saveProactiveMemory(trigger, delivered = false) {
    try {
      const memoryIds = trigger.memories.map((m) => m.id);
      this.db
        .prepare(
          `
        INSERT INTO proactive_memories (trigger_type, trigger_date, memory_ids, delivered_at, viewed_at, dismissed_at)
        VALUES (?, ?, ?, ?, ?, ?)
      `
        )
        .run(
          trigger.trigger_type,
          trigger.trigger_date,
          JSON.stringify(memoryIds),
          delivered ? new Date().toISOString() : null,
          null,
          null
        );
    } catch (error) {
      console.error('❌ Error saving proactive memory:', error.message);
    }
  }

  markAsViewed(proactiveId) {
    try {
      this.db
        .prepare('UPDATE proactive_memories SET viewed_at = ? WHERE id = ?')
        .run(new Date().toISOString(), proactiveId);
    } catch (error) {
      console.error('❌ Error marking proactive memory as viewed:', error.message);
    }
  }

  markAsDismissed(proactiveId) {
    try {
      this.db
        .prepare('UPDATE proactive_memories SET dismissed_at = ? WHERE id = ?')
        .run(new Date().toISOString(), proactiveId);
    } catch (error) {
      console.error('❌ Error marking proactive memory as dismissed:', error.message);
    }
  }

  wasAlreadyViewedToday(triggerType, triggerDate) {
    try {
      const existing = this.db
        .prepare(
          `
        SELECT id FROM proactive_memories
        WHERE trigger_type = ? AND trigger_date = ? AND viewed_at IS NOT NULL
        LIMIT 1
      `
        )
        .get(triggerType, triggerDate);
      return !!existing;
    } catch (error) {
      console.error('❌ Error checking if trigger was viewed:', error.message);
      return false;
    }
  }

  getPendingTriggerToday(triggerType, triggerDate) {
    try {
      const existing = this.db
        .prepare(
          `
        SELECT * FROM proactive_memories
        WHERE trigger_type = ? AND trigger_date = ?
        AND delivered_at IS NOT NULL
        AND viewed_at IS NULL
        AND dismissed_at IS NULL
        LIMIT 1
      `
        )
        .get(triggerType, triggerDate);
      return existing;
    } catch (error) {
      console.error('❌ Error checking for pending trigger:', error.message);
      return null;
    }
  }

  async _buildCinematicExperience(trigger) {
    try {
      console.log(
        `[Proactive Service] ↳ Building cinematic experience for trigger: '${trigger.trigger_type}'...`
      );
      const axios = require('axios');
      const BACKEND_URL = process.env.BACKEND_URL || 'http://127.0.0.1:3000';
      const AUTH_TOKEN = process.env.AUTH_TOKEN;

      const memoryTitles = trigger.memories.map((m) => m.title).join(', ');
      const query = `Create a beautiful cinematic memory experience for these ${trigger.trigger_type} memories: ${memoryTitles}. Context: ${trigger.description}. Please make this a special, immersive cinematic show to celebrate these precious moments.`;

      const preselected_memory_ids = trigger.memories.map((m) => m.id);

      const payload = {
        query,
        preselected_memory_ids: preselected_memory_ids,
      };

      console.log(
        `[Proactive Service]   → Calling /chat endpoint with PRESELECTED IDs: [${preselected_memory_ids.join(', ')}]`
      );

      const response = await axios.post(`${BACKEND_URL}/api/memories/chat`, payload, {
        headers: {
          'x-auth-token': AUTH_TOKEN,
          'Content-Type': 'application/json',
        },
      });

      if (response.data && response.data.response_type) {
        console.log(
          `[Proactive Service]   ✓ AI Director returned a '${response.data.response_type}' successfully.`
        );
        return response.data;
      } else {
        throw new Error('Director returned invalid response');
      }
    } catch (error) {
      console.error(
        `[Proactive Service]   ❌ Failed to get response from AI Director.`
      );
      return false;
    }
  }

  _formatMonthDay(date) {
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${month}-${day}`;
  }

  _getCurrentSeason(month) {
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'fall';
    return 'winter';
  }

  _isSeasonallyRelevant(tags, currentMonth) {
    const seasonalMap = {
      12: ['christmas', 'winter', 'holiday', 'xmas'],
      1: ['winter', 'holiday'],
      2: ['winter'],
      3: ['spring'],
      4: ['spring', 'easter'],
      5: ['spring'],
      6: ['summer', 'beach', 'vacation'],
      7: ['summer', 'beach', 'vacation'],
      8: ['summer', 'beach', 'vacation'],
      9: ['fall'],
      10: ['fall', 'halloween', 'costume', 'spooky'],
      11: ['fall', 'thanksgiving', 'turkey'],
    };
    const relevantTags = seasonalMap[currentMonth] || [];
    return tags.some((tag) => relevantTags.includes(tag.toLowerCase()));
  }

  _generateOnThisDayTitle(memories) {
    const years = memories.map(
      (m) => new Date().getFullYear() - new Date(m.whenWasThis || m.timestamp).getFullYear()
    );
    const minYears = Math.min(...years);
    if (memories.length === 1) {
      return `On This Day ${minYears} Years Ago`;
    }
    return `On This Day - ${memories.length} Special Memories`;
  }

  _generateAnniversaryTitle(memories) {
    const anniversaryTypes = [...new Set(memories.map((m) => m.anniversary_type))];
    if (anniversaryTypes.length === 1) {
      const type = anniversaryTypes[0];
      switch (type) {
        case 'wedding':
          return 'Your Wedding Anniversary';
        case 'graduation':
          return 'Your Graduation Anniversary';
        case 'birthday':
          return 'Birthday Memories';
        case 'work':
          return 'Career Milestone Anniversary';
        default:
          return 'Special Anniversary';
      }
    }
    return 'Special Anniversaries Today';
  }

  _generateSeasonalTitle(memories, season) {
    const seasonTitles = {
      spring: 'Spring Memories',
      summer: 'Summer Adventures',
      fall: 'Autumn Remembrances',
      winter: 'Winter Moments',
    };
    return seasonTitles[season] || 'Seasonal Memories';
  }
}

module.exports = ProactiveTriggerService;