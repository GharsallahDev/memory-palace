# services/transcription_service.py
import logging
import torch
import warnings
import tempfile
import os
from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor, pipeline
from typing import Union

logger = logging.getLogger(__name__)

class TranscriptionService:
    """Service for transcribing audio files using a Whisper model."""
    def __init__(self):
        self.pipe = None
        self.device = "cuda:0" if torch.cuda.is_available() else "cpu"
        self._is_ready = False
        warnings.filterwarnings("ignore", category=FutureWarning)
        self._initialize()

    def _initialize(self):
        """Loads the Whisper model and creates the transcription pipeline."""
        if self._is_ready:
            return
        try:
            logger.info(f"Initializing Transcription Service on device: '{self.device}'...")
            torch_dtype = torch.float16 if "cuda" in self.device else torch.float32
            model_id = "openai/whisper-large-v3-turbo"
            model = AutoModelForSpeechSeq2Seq.from_pretrained(
                model_id, torch_dtype=torch_dtype, low_cpu_mem_usage=True, use_safetensors=True
            ).to(self.device)
            processor = AutoProcessor.from_pretrained(model_id)
            self.pipe = pipeline(
                "automatic-speech-recognition", model=model, tokenizer=processor.tokenizer,
                feature_extractor=processor.feature_extractor, torch_dtype=torch_dtype, device=self.device,
                chunk_length_s=30, stride_length_s=5, ignore_warning=True
            )
            self._is_ready = True
            logger.info("Transcription Service (Whisper) initialized successfully.")
        except Exception as e:
            logger.error(f"Failed to initialize Transcription Service: {e}", exc_info=True)
            self._is_ready = False

    def is_ready(self) -> bool:
        return self._is_ready

    def transcribe_audio(self, audio_data: Union[str, bytes]) -> dict:
        """Transcribes an audio file and returns the full result with timestamps."""
        if not self.is_ready() or not self.pipe:
            raise Exception("Transcription service is not ready.")
        
        try:
            if isinstance(audio_data, bytes):
                with tempfile.NamedTemporaryFile(delete=False, suffix='.webm') as temp_file:
                    temp_file.write(audio_data)
                    temp_file_path = temp_file.name
                try:
                    result = self.pipe(temp_file_path, return_timestamps=True, generate_kwargs={"language": "english"})
                finally:
                    os.unlink(temp_file_path)
            else:
                result = self.pipe(audio_data, return_timestamps=True, generate_kwargs={"language": "english"})
            
            return {
                "text": result.get("text", "").strip(),
                "chunks": result.get("chunks", [])
            }
        except Exception as e:
            logger.error(f"Failed to transcribe audio: {e}", exc_info=True)
            raise