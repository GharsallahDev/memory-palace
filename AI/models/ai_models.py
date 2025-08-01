# models/ai_models.py
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any, Union, Literal
from datetime import datetime, timezone

class ProcessingStats(BaseModel):
    """Model for tracking request processing performance."""
    start_time: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    end_time: Optional[datetime] = None
    processing_time_ms: float = 0

    def finish(self):
        if self.end_time is None:
            self.end_time = datetime.now(timezone.utc)
            if self.start_time:
                self.processing_time_ms = (self.end_time - self.start_time).total_seconds() * 1000

class EmbeddingRequest(BaseModel):
    text: str

class EmbeddingResponse(BaseModel):
    vector: List[float]

class TtsRequest(BaseModel):
    text: str

class MemoryAnalysisRequest(BaseModel):
    title: str
    description: str
    type: str
    date: Optional[str] = None
    location: Optional[str] = None
    people_present: Optional[List[str]] = None

class MemoryAnalysisResponse(BaseModel):
    anniversary_type: Optional[str] = None
    seasonal_tags: List[str] = []
    proactive_score: float = 0.0
    reasoning: str = ""

class MemoryContext(BaseModel):
    memory_id: str
    type: str
    description: str

class PatientContext(BaseModel):
    name: str
    age: Optional[int] = None
    description: str

class ChatRequest(BaseModel):
    query: str
    context_memories: List[MemoryContext] = []
    patient_context: Optional[PatientContext] = None
    conversation_type: Optional[str] = "memory_based"

class Scene(BaseModel):
    memory_id: str
    narration: str

class CinematicShow(BaseModel):
    response_type: Literal["cinematic_show"] = "cinematic_show"
    show_title: str
    scenes: List[Scene]

class NarrativeResponse(BaseModel):
    response_type: Literal["narrative"] = "narrative"
    message: str

DirectorResponse = Union[CinematicShow, NarrativeResponse]

class HealthResponse(BaseModel):
    status: str
    services: Dict[str, bool]
    version: str
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))