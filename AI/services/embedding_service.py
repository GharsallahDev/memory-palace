# services/embedding_service.py
import logging
import torch
from transformers import AutoTokenizer, AutoModel
from typing import List

logger = logging.getLogger(__name__)

class EmbeddingService:
    """Service for generating text embeddings using sentence-transformers."""
    def __init__(self):
        self.tokenizer = None
        self.model = None
        self.model_id = "sentence-transformers/all-MiniLM-L6-v2"
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self._is_ready = False
        self._initialize()

    def _initialize(self):
        """Initializes the tokenizer and model from Hugging Face."""
        try:
            logger.info(f"Initializing Embedding Service on device: '{self.device}'...")
            self.tokenizer = AutoTokenizer.from_pretrained(self.model_id)
            self.model = AutoModel.from_pretrained(self.model_id).to(self.device)
            self._is_ready = True
            logger.info(f"Embedding Service (transformers) ready. Using model '{self.model_id}'.")
        except Exception as e:
            logger.error(f"Failed to initialize Embedding Service: {e}", exc_info=True)
            self._is_ready = False

    def is_ready(self) -> bool:
        """Check if the service and its model are loaded."""
        return self._is_ready

    def _mean_pooling(self, model_output, attention_mask):
        """Performs mean pooling on token embeddings to get a single sentence vector."""
        token_embeddings = model_output[0]
        input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
        return torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)

    def generate_embedding(self, text: str) -> List[float]:
        """Generates a vector embedding for a given string of text."""
        if not self.is_ready():
            raise Exception("Embedding service is not available.")
        
        try:
            encoded_input = self.tokenizer(
                [text],
                padding=True,
                truncation=True,
                return_tensors='pt'
            ).to(self.device)

            with torch.no_grad():
                model_output = self.model(**encoded_input)

            sentence_embedding = self._mean_pooling(model_output, encoded_input['attention_mask'])
            normalized_embedding = torch.nn.functional.normalize(sentence_embedding, p=2, dim=1)
            
            return normalized_embedding[0].tolist()
        except Exception as e:
            logger.error(f"Failed to generate text embedding: {e}", exc_info=True)
            raise