# services/proactive_analysis_service.py
import logging
import json
import ollama
from typing import Dict, List, Any

logger = logging.getLogger(__name__)

class ProactiveAnalysisService:
    """Service for analyzing memories for proactive triggers."""
    def __init__(self):
        self.client = None
        self.model_name = "gemma3n:e2b"
        self._is_ready = False
        self._initialize()

    def _initialize(self):
        """Initialize the Ollama client for analysis."""
        try:
            self.client = ollama.Client()
            self.client.show(self.model_name)
            self._is_ready = True
            logger.info(f"Proactive Analysis Service ready. Using model '{self.model_name}'.")
        except Exception as e:
            logger.error(f"Failed to initialize Proactive Analysis service for model '{self.model_name}': {e}", exc_info=True)
            self.client = None
            self._is_ready = False

    def is_ready(self) -> bool:
        return self._is_ready

    def _construct_analysis_prompt(self, memory_title: str, memory_description: str,
                                 memory_type: str, memory_date: str = None,
                                 memory_location: str = None, people_present: List[str] = None) -> str:
        """Constructs a focused prompt for memory analysis."""
        prompt = "You are a memory analysis AI. Analyze the given memory for proactive trigger potential based on Anniversary type, Seasonal relevance, and a Proactive score (0-5)."
        prompt += "\n\nMEMORY TO ANALYZE:"
        prompt += f"\nTitle: \"{memory_title}\""
        prompt += f"\nDescription: \"{memory_description}\""
        prompt += f"\nType: {memory_type}"
        if memory_date: prompt += f"\nDate: {memory_date}"
        if memory_location: prompt += f"\nLocation: {memory_location}"
        if people_present: prompt += f"\nPeople Present: {', '.join(people_present)}"
        prompt += """

ANNIVERSARY TYPES (select ONE or null): "work", "graduation", "birthday", "wedding", "anniversary", "retirement", "death".
SEASONAL TAGS (only if EXPLICITLY mentioned): christmas, halloween, thanksgiving, birthday, vacation, summer, winter, etc.
PROACTIVE SCORE (0-5): 5 for major life events, 3 for holidays, 1 for casual events, 0 for mundane.

CRITICAL: Respond with ONLY a JSON object in this exact format:
{
  "anniversary_type": "work",
  "seasonal_tags": ["competition", "sports"],
  "proactive_score": 4,
  "reasoning": "Brief explanation of your analysis."
}"""
        return prompt

    async def analyze_memory(self, memory_title: str, memory_description: str,
                           memory_type: str, memory_date: str = None,
                           memory_location: str = None, people_present: List[str] = None) -> Dict[str, Any]:
        """Analyzes a memory and returns a structured dictionary of its proactive potential."""
        if not self.is_ready():
            return self._get_default_analysis()

        raw_json = ""
        try:
            prompt = self._construct_analysis_prompt(
                memory_title, memory_description, memory_type,
                memory_date, memory_location, people_present
            )
            response = self.client.chat(
                model=self.model_name,
                messages=[{'role': 'user', 'content': prompt}],
                stream=False,
                format='json',
                options={'temperature': 0.1}
            )
            raw_json = response['message']['content']
            analysis_result = json.loads(raw_json)
            return self._validate_analysis_result(analysis_result)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse analysis JSON from model. Raw response: {raw_json}", exc_info=True)
            return self._get_default_analysis()
        except Exception as e:
            logger.error(f"Memory analysis failed for title '{memory_title}': {e}", exc_info=True)
            return self._get_default_analysis()

    def _validate_analysis_result(self, raw_result: Dict[str, Any]) -> Dict[str, Any]:
        """Validates and cleans the analysis result from the AI."""
        anniversary_type = raw_result.get("anniversary_type")
        if anniversary_type == "null": anniversary_type = None

        seasonal_tags = raw_result.get("seasonal_tags", [])
        if not isinstance(seasonal_tags, list): seasonal_tags = []

        proactive_score = raw_result.get("proactive_score", 0)
        try:
            proactive_score = max(0, min(5, float(proactive_score)))
        except (ValueError, TypeError):
            proactive_score = 0
            
        return {
            "anniversary_type": anniversary_type,
            "seasonal_tags": seasonal_tags[:3],
            "proactive_score": proactive_score,
            "reasoning": raw_result.get("reasoning", "No reasoning provided.")
        }

    def _get_default_analysis(self) -> Dict[str, Any]:
        """Returns default analysis when the primary analysis fails."""
        return {
            "anniversary_type": None,
            "seasonal_tags": [],
            "proactive_score": 0,
            "reasoning": "Analysis failed, using default values."
        }