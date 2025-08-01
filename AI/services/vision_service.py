# services/vision_service.py
import logging
import torch
from PIL import Image
import io
from transformers import BlipProcessor, BlipForConditionalGeneration

logger = logging.getLogger(__name__)

class VisionService:
    """
    Service for handling local image captioning using the BLIP model.
    This runs entirely on the local machine.
    """
    
    def __init__(self):
        self.processor = None
        self.model = None
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model_id = "Salesforce/blip-image-captioning-base"
        self._is_ready = False
        
        self._initialize()

    def _initialize(self):
        """Loads the BLIP model and processor into memory."""
        logger.info(f"🔧 Initializing Vision Service on device: '{self.device}'...")
        if self._is_ready:
            return

        try:
            torch_dtype = torch.float16 if self.device == "cuda" else torch.float32

            logger.info(f"📚 Loading BLIP model: '{self.model_id}'...")
            self.processor = BlipProcessor.from_pretrained(self.model_id)
            self.model = BlipForConditionalGeneration.from_pretrained(
                self.model_id,
                torch_dtype=torch_dtype,
                use_safetensors=True
            ).to(self.device)
            
            self._is_ready = True
            logger.info("✅ Vision Service (BLIP) initialized successfully.")

        except Exception as e:
            logger.error(f"❌ Failed to initialize Vision Service: {e}", exc_info=True)
            logger.error("❌ Please ensure you have an internet connection for the first download and sufficient disk space.")
            self._is_ready = False
            raise

    def is_ready(self) -> bool:
        """Check if the service and its models are loaded."""
        return self._is_ready

    def generate_caption(self, image_bytes: bytes) -> str:
        """Generates a caption for a given image."""
        if not self.is_ready() or not self.model or not self.processor:
            raise Exception("Vision service is not ready.")

        try:
            raw_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
            
            inputs = self.processor(images=raw_image, return_tensors="pt").to(self.device)
            
            if self.device == "cpu":
                inputs = {key: val.to(torch.float32) for key, val in inputs.items()}
            
            output_ids = self.model.generate(**inputs, max_new_tokens=50)
            caption = self.processor.decode(output_ids[0], skip_special_tokens=True)
            
            if caption.lower().startswith("arafed image of"):
                caption = caption[len("arafed image of"):].strip()
            
            caption = caption.capitalize()

            logger.info(f"✅ Generated image caption: '{caption}'")
            return caption

        except Exception as e:
            logger.error(f"❌ Failed to generate image caption with BLIP model: {e}")
            raise