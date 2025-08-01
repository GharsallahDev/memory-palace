# app.py
import os
import logging
from contextlib import asynccontextmanager
import io
from fastapi import FastAPI, HTTPException, File, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from typing import Optional, List
import uvicorn
from dotenv import load_dotenv
from pydantic import BaseModel

from services.chat_service import ChatService
from services.proactive_analysis_service import ProactiveAnalysisService
from services.vision_service import VisionService
from services.transcription_service import TranscriptionService
from services.face_recognition_service import FaceRecognitionService
from services.embedding_service import EmbeddingService
from services.tts_service import TtsService
from models.ai_models import (
    ChatRequest, DirectorResponse, HealthResponse,
    EmbeddingRequest, EmbeddingResponse, TtsRequest,
    MemoryAnalysisRequest, MemoryAnalysisResponse
)

# --- Logging Configuration (CLEANED UP) ---
# Configure root logger for general info, but raise level for noisy libraries
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("TTS").setLevel(logging.ERROR)
logging.getLogger("watchfiles").setLevel(logging.WARNING)

logger = logging.getLogger(__name__)
load_dotenv()


# --- Pydantic Models for Recognition Endpoint ---
class KnownFacePayload(BaseModel):
    person_id: int
    name: str
    avatar_base_64: str

class RecognitionRequest(BaseModel):
    photo_to_check_base64: str
    known_faces: List[KnownFacePayload]

# --- Global Service Variables ---
chat_service: Optional[ChatService] = None
proactive_analysis_service: Optional[ProactiveAnalysisService] = None
vision_service: Optional[VisionService] = None
transcription_service: Optional[TranscriptionService] = None
face_recognition_service: Optional[FaceRecognitionService] = None
embedding_service: Optional[EmbeddingService] = None
tts_service: Optional[TtsService] = None

# --- Lifespan Manager ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    global chat_service, proactive_analysis_service, vision_service, transcription_service, face_recognition_service, embedding_service, tts_service

    logger.info("🤖 Initializing Memory Palace AI Service...")

    try:
        # Initialize all services
        chat_service = ChatService()
        proactive_analysis_service = ProactiveAnalysisService()
        vision_service = VisionService()
        transcription_service = TranscriptionService()
        face_recognition_service = FaceRecognitionService()
        embedding_service = EmbeddingService()
        tts_service = TtsService()

        logger.info("✅ All AI services initialized successfully!")

    except Exception as e:
        logger.error(f"❌ Critical AI service failed to initialize: {str(e)}")
        # Allow the app to start to see the health check, but services will be down
        # raise # This would stop the app completely

    yield

    logger.info("🔄 Shutting down AI services...")

# --- FastAPI App ---
app = FastAPI(title="Memory Palace AI Service", version="5.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

# --- HEALTH CHECK ---
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Check the health of all AI services."""
    services_status = {
        "chat_conversation": chat_service.is_ready() if chat_service else False,
        "proactive_analysis": proactive_analysis_service.is_ready() if proactive_analysis_service else False,
        "blip_vision": vision_service.is_ready() if vision_service else False,
        "whisper_transcription": transcription_service.is_ready() if transcription_service else False,
        "face_recognition": face_recognition_service.is_ready() if face_recognition_service else False,
        "nomic_embedding": embedding_service.is_ready() if embedding_service else False,
        "gtts_tts": tts_service.is_ready() if tts_service else False,
    }

    all_healthy = all(services_status.values())

    return HealthResponse(
        status="healthy" if all_healthy else "degraded",
        services=services_status,
        version="5.0.0",
    )

# --- CONVERSATION ENDPOINT (CLEANED UP) ---
@app.post("/chat", response_model=DirectorResponse)
async def chat(request: ChatRequest):
    """
    Handle conversational interactions ONLY.
    No analysis requests allowed here.
    """
    if not chat_service or not chat_service.is_ready():
        raise HTTPException(
            status_code=503,
            detail="Conversation service is not available."
        )

    return await chat_service.generate_response(request)

# --- NEW ANALYSIS ENDPOINT ---
@app.post("/analyze-memory", response_model=MemoryAnalysisResponse)
async def analyze_memory(request: MemoryAnalysisRequest):
    """
    Analyze a memory for proactive triggers.
    Completely separate from conversation logic.
    """
    if not proactive_analysis_service or not proactive_analysis_service.is_ready():
        raise HTTPException(
            status_code=503,
            detail="Memory analysis service is not available."
        )

    try:
        logger.info(f"🧠 Analyzing memory for proactive triggers. Title: '{request.title}'")
        result = await proactive_analysis_service.analyze_memory(
            memory_title=request.title,
            memory_description=request.description,
            memory_type=request.type,
            memory_date=request.date,
            memory_location=request.location,
            people_present=request.people_present
        )
        logger.info(f"  ✓ Analysis complete. Score: {result.get('proactive_score')}, Anniversary: {result.get('anniversary_type')}")

        return MemoryAnalysisResponse(**result)

    except Exception as e:
        logger.error(f"Memory analysis failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# --- EMBEDDING ENDPOINT ---
@app.post("/generate-embedding", response_model=EmbeddingResponse)
async def generate_embedding(request: EmbeddingRequest):
    """Generate text embeddings for similarity search."""
    if not embedding_service or not embedding_service.is_ready():
        raise HTTPException(
            status_code=503,
            detail="Text embedding service is not available."
        )

    try:
        vector = await run_in_threadpool(embedding_service.generate_embedding, request.text)
        return EmbeddingResponse(vector=vector)
    except Exception as e:
        logger.error(f"Embedding generation failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# --- TTS ENDPOINT ---
@app.post("/generate-speech")
async def generate_speech(request: TtsRequest):
    """Generate speech from text."""
    if not tts_service or not tts_service.is_ready():
        raise HTTPException(
            status_code=503,
            detail="Text-to-Speech service is not available."
        )

    # *** THIS BLOCK IS NOW FIXED WITH CORRECT PYTHON SYNTAX ***
    try:
        logger.info(f"🗣️ Generating speech for text: \"{request.text[:80]}...\"")
        audio_bytes, duration_ms = await run_in_threadpool(tts_service.generate_speech, request.text)
        logger.info(f"  ✓ Speech generated successfully ({duration_ms}ms duration).")

        headers = {"X-Audio-Duration-Ms": str(duration_ms)}

        return StreamingResponse(
            io.BytesIO(audio_bytes),
            media_type="audio/mp3",
            headers=headers
        )
    except Exception as e:
        logger.error(f"Speech generation failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# --- VISION ENDPOINT ---
@app.post("/describe-image", response_model=dict)
async def describe_image(image: UploadFile = File(...)):
    """Generate captions for images."""
    if not vision_service or not vision_service.is_ready():
        raise HTTPException(
            status_code=503,
            detail="Image captioning service is not available."
        )

    image_bytes = await image.read()
    caption = await run_in_threadpool(vision_service.generate_caption, image_bytes)
    return {"caption": caption}

# --- TRANSCRIPTION ENDPOINT ---
@app.post("/transcribe-audio", response_model=dict)
async def transcribe_audio(audio: UploadFile = File(...)):
    """Transcribe audio files to text."""
    if not transcription_service or not transcription_service.is_ready():
        raise HTTPException(
            status_code=503,
            detail="Audio transcription service is not available."
        )

    audio_bytes = await audio.read()
    logger.info(f"🎤 Transcribing audio file '{audio.filename}' ({len(audio_bytes)} bytes)...")

    transcription_result = await run_in_threadpool(
        transcription_service.transcribe_audio,
        audio_bytes
    )
    return transcription_result

# --- FACE RECOGNITION ENDPOINT ---
@app.post("/recognize-people")
async def recognize_people_in_photo(request: RecognitionRequest):
    """Recognize people in photos using known faces."""
    if not face_recognition_service or not face_recognition_service.is_ready():
        raise HTTPException(
            status_code=503,
            detail="Face recognition service is not available."
        )

    try:
        recognized_people = await face_recognition_service.identify_people(
            request.photo_to_check_base64,
            request.known_faces
        )
        return {"recognized_people": recognized_people}
    except Exception as e:
        logger.error(f"Face recognition failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

# --- GLOBAL EXCEPTION HANDLER ---
@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    logger.error(f"Unhandled exception: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={"detail": f"Internal server error: {str(exc)}"}
    )

if __name__ == "__main__":
    port = int(os.getenv("AI_SERVICE_PORT", 5000))
    host = os.getenv("AI_SERVICE_HOST", "127.0.0.1")
    logger.info(f"🚀 Starting Memory Palace AI Service on http://{host}:{port}")
    uvicorn.run("app:app", host=host, port=port, reload=True)