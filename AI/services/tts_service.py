# services/tts_service.py
import logging
import os
import tempfile
from typing import Tuple
from TTS.api import TTS
import soundfile as sf

logger = logging.getLogger(__name__)

class TtsService:
    """TTS service using Coqui TTS for high-quality offline text-to-speech."""
    def __init__(self):
        self._is_ready = False
        self._model = None
        self._initialize()

    def _initialize(self):
        """Initialize the TTS service and load the model."""
        try:
            logger.info("Initializing TTS Service with Coqui TTS...")
            os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
            self._model = TTS("tts_models/en/ljspeech/overflow", progress_bar=False)
            self._is_ready = True
            logger.info("TTS Service (Coqui TTS) ready.")
        except Exception as e:
            logger.error(f"Failed to initialize TTS Service: {e}", exc_info=True)
            self._is_ready = False
            raise

    def is_ready(self) -> bool:
        return self._is_ready

    def generate_speech(self, text: str) -> Tuple[bytes, int]:
        """
        Generates speech for a given string of text.
        Returns a tuple of (audio_bytes, duration_in_milliseconds).
        """
        if not self.is_ready() or not self._model:
            raise Exception("TTS service is not available.")
        
        try:
            with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_file:
                temp_file_path = temp_file.name
            
            try:
                self._model.tts_to_file(text=text, file_path=temp_file_path)
                
                with open(temp_file_path, 'rb') as f:
                    audio_bytes = f.read()
                
                audio_data, sample_rate = sf.read(temp_file_path)
                duration_ms = int((len(audio_data) / sample_rate) * 1000)
                
                return audio_bytes, duration_ms
            finally:
                if os.path.exists(temp_file_path):
                    os.unlink(temp_file_path)
        except Exception as e:
            logger.error(f"Failed to generate speech for text '{text[:50]}...': {e}", exc_info=True)
            raise