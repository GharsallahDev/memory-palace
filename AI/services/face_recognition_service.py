# services/face_recognition_service.py
import logging
import face_recognition
import numpy as np
import io
import base64
from typing import List, Dict, Any
from pydantic import BaseModel

logger = logging.getLogger(__name__)

class KnownFacePayload(BaseModel):
    person_id: int
    name: str
    avatar_base_64: str

class FaceRecognitionService:
    def __init__(self):
        self.model = "hog"
        self._is_ready = False
        self._initialize()

    def _initialize(self):
        try:
            face_recognition.face_locations(np.zeros((10, 10, 3), dtype=np.uint8))
            self._is_ready = True
            logger.info("Face Recognition Service initialized successfully.")
        except Exception as e:
            logger.error(f"Failed to initialize Face Recognition Service: {e}", exc_info=True)
            self._is_ready = False

    def is_ready(self) -> bool:
        return self._is_ready

    async def identify_people(self, photo_to_check_base64: str, known_faces_payload: List[KnownFacePayload]) -> List[Dict[str, Any]]:
        if not self.is_ready():
            raise Exception("Face Recognition service is not ready.")
        if not known_faces_payload:
            return []

        known_face_encodings = []
        known_face_metadata = []
        for person_data in known_faces_payload:
            try:
                avatar_bytes = base64.b64decode(person_data.avatar_base_64)
                avatar_image = face_recognition.load_image_file(io.BytesIO(avatar_bytes))
                avatar_encodings = face_recognition.face_encodings(avatar_image)
                if avatar_encodings:
                    known_face_encodings.append(avatar_encodings[0])
                    known_face_metadata.append({"person_id": person_data.person_id, "name": person_data.name})
            except Exception as e:
                logger.warning(f"Could not load or encode avatar for person_id {person_data.person_id}: {e}")

        if not known_face_encodings:
            return []

        try:
            unknown_image_bytes = base64.b64decode(photo_to_check_base64)
            unknown_image = face_recognition.load_image_file(io.BytesIO(unknown_image_bytes))
            unknown_face_locations = face_recognition.face_locations(unknown_image, model=self.model)
            unknown_face_encodings = face_recognition.face_encodings(unknown_image, unknown_face_locations)
        except Exception as e:
            logger.error(f"Failed to process the photo to check for faces: {e}", exc_info=True)
            return []

        recognized_people = []
        for face_encoding in unknown_face_encodings:
            matches = face_recognition.compare_faces(known_face_encodings, face_encoding, tolerance=0.6)
            if True in matches:
                first_match_index = matches.index(True)
                match_metadata = known_face_metadata[first_match_index]
                person_id = match_metadata['person_id']
                if not any(p['person_id'] == person_id for p in recognized_people):
                    recognized_people.append({"person_id": person_id, "name": match_metadata['name']})
        return recognized_people