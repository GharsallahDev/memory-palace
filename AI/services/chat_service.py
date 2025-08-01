# services/chat_service.py
import logging
import json
import ollama

from models.ai_models import (
    ChatRequest,
    DirectorResponse,
    NarrativeResponse,
    CinematicShow,
    ProcessingStats
)

logger = logging.getLogger(__name__)

class ChatService:
    def __init__(self):
        self.client = None
        self.model_name = "gemma3n:e2b"
        self._is_ready = False
        self._initialize()

    def _initialize(self):
        try:
            self.client = ollama.Client()
            logger.info("🔧 Initializing Gemma Service...")
            self.client.show(self.model_name)
            self._is_ready = True
            logger.info(f"✅ Gemma Service ready. Using model '{self.model_name}'.")
        except Exception as e:
            logger.error(f"❌ Failed to initialize Gemma service with model '{self.model_name}'.")
            logger.error(f"Ensure Ollama is running and the model has been pulled ('ollama pull {self.model_name}').")
            logger.error(f"Underlying error: {e}")
            self.client = None
            self._is_ready = False

    def is_ready(self) -> bool:
        return self._is_ready

    def _construct_prompt(self, request: ChatRequest) -> str:
        conversation_type = getattr(request, 'conversation_type', 'memory_based')
        
        prompt = "You are an AI assistant for a system called 'The Memory Palace', speaking to an elderly user with memory loss. Your tone must be warm, gentle, patient, and reassuring."

        prompt += "\n\n--- JSON OUTPUT STRUCTURE ---"
        prompt += "\nYour entire response MUST be a single, valid JSON object. Choose the appropriate format:"
        prompt += '\n1. NARRATIVE: {"response_type": "narrative", "message": "Your response"}'
        prompt += '\n2. CINEMATIC: {"response_type": "cinematic_show", "show_title": "Title", "scenes": [{"memory_id": "id", "narration": "text"}]}'

        if conversation_type == "casual":
            prompt += "\n\n--- CASUAL CONVERSATION MODE ---"
            prompt += "\nThe user is having a casual conversation with no specific memories provided."
            prompt += "\nRespond warmly and naturally using NARRATIVE format."
            prompt += "\nYou can ask how they're feeling, what they'd like to talk about, or just be a friendly companion."
            
        elif conversation_type == "memory_based":
            prompt += "\n\n--- MEMORY CONVERSATION MODE ---"
            prompt += "\nThe user is asking about memories. Relevant memories have been provided below."
            
            has_visual = any(mem.type in ['photo', 'video'] for mem in request.context_memories)
            
            if has_visual:
                visual_count = len([mem for mem in request.context_memories if mem.type in ['photo', 'video']])
                prompt += f"\nSince {visual_count} visual memories (photos/videos) are available, use CINEMATIC format."
                prompt += f"\nYou MUST create exactly {visual_count} scenes - one for each visual memory provided."
                prompt += f"\nDO NOT skip any memories. Include ALL {visual_count} visual memories as separate scenes."
            else:
                prompt += "\nOnly text/voice memories are available, so use NARRATIVE format."
                prompt += "\nWeave the memory information naturally into your response."
        
        if request.query == 'The user showed me a photo I recognize. Please describe the following memory to them in a warm, narrative style. Do not make it a cinematic show.':
            prompt += "\n\n--- PHOTO RECOGNITION OVERRIDE ---"
            prompt += "\nThis is a specific photo the user showed. Use NARRATIVE format to describe this specific memory warmly."

        prompt += "\n\n--- IMPORTANT RULES ---"
        prompt += "\n- Base responses ONLY on the provided memory descriptions and Patient Status notes."
        prompt += "\n- If a person's relationship is in parentheses (e.g., 'Kate (Daughter)'), use it in your narration, for example, by saying 'your daughter, Kate'."
        prompt += "\n- CRITICAL: If any memory description refers to 'You', it means the patient. Treat 'You' as referring to the patient and respond accordingly."
        prompt += "\n- For cinematic shows: memory_id must match exactly from the provided memories"
        prompt += "\n- Show titles should be personal and address the patient in second person"
        prompt += "\n- IMPORTANT: For video memories, keep the narration SHORT and concise. Video narrations should be brief and to the point."
        prompt += "\n- DO NOT hallucinate details not present in the memory descriptions"

        patient_name = ""
        if request.patient_context:
            patient_name = request.patient_context.name
            prompt += f"\n\n--- PATIENT INFO ---\nName: {request.patient_context.name}"
            if hasattr(request.patient_context, 'age') and request.patient_context.age:
                prompt += f"\nAge: {request.patient_context.age}"
            if hasattr(request.patient_context, 'description') and request.patient_context.description:
                prompt += f"\nNotes: {request.patient_context.description}"
        
        if request.context_memories and len(request.context_memories) > 0:
            visual_memories = [mem for mem in request.context_memories if mem.type in ['photo', 'video']]
            prompt += f"\n\n--- RELEVANT MEMORIES ---"
            for i, mem in enumerate(request.context_memories):
                prompt += f"\nMemory {i+1} (ID: {mem.memory_id}):"
                prompt += f"\n{mem.description}"

                if patient_name:
                    patient_is_present = (patient_name.lower() in mem.description.lower() or 
                                        " you " in mem.description.lower() or 
                                        mem.description.lower().startswith("you ") or
                                        mem.description.lower().endswith(" you"))
                    if patient_is_present:
                        prompt += f'\nPatient Status: PRESENT. The patient, {patient_name}, is in this memory. You MUST refer to him as "you".'
                    else:
                        prompt += f'\nPatient Status: NOT PRESENT. The patient is NOT in this memory. You MUST refer to all people by their names.'
                prompt += "\n"
            
            if visual_memories:
                prompt += f"\n--- MANDATORY SCENE CREATION ---"
                prompt += f"\nYou MUST create {len(visual_memories)} scenes using these exact memory IDs:"
                for i, mem in enumerate(visual_memories):
                    prompt += f"\n- Scene {i+1}: memory_id '{mem.memory_id}' ({mem.type})"
                    if mem.type == 'video':
                        prompt += f" - KEEP NARRATION SHORT"
                prompt += f"\nDO NOT create fewer than {len(visual_memories)} scenes. Each visual memory MUST have its own scene."
        else:
            prompt += f"\n\n--- NO RELEVANT MEMORIES ---"
            prompt += f"\nNo specific memories were found related to this query."

        prompt += f"\n\n--- RESPOND NOW ---"
        prompt += f"\nUser Query: '{request.query}'"
        if conversation_type == "casual":
            prompt += f"\nProvide a warm, casual response using NARRATIVE format."
        else:
            prompt += f"\nProvide an appropriate response based on the memories and rules above."

        logger.info(f"Constructed Prompt: \n{prompt}")
        return prompt

    async def generate_response(self, request: ChatRequest) -> DirectorResponse:
        stats = ProcessingStats()
        
        if not self.is_ready():
            return NarrativeResponse(message="Error: The AI Director service is not available or the configured model is not installed.")

        prompt = self._construct_prompt(request)
        try:
            logger.info(f"Generating Director response for query: '{request.query}' using model '{self.model_name}'")
            ollama_response = self.client.chat(
                model=self.model_name,
                messages=[{'role': 'user', 'content': prompt}],
                stream=False,
                format='json',
                options={'temperature': 0.1}
            )
            raw_json_output = ollama_response['message']['content']
            
            logger.info(f"Raw AI JSON output: {raw_json_output}")
            
            response_data = json.loads(raw_json_output)

            if response_data.get("response_type") == "cinematic_show":
                return CinematicShow(**response_data)
            elif response_data.get("response_type") == "narrative":
                return NarrativeResponse(**response_data)
            else:
                raise ValueError("AI returned an unknown or missing response_type.")

        except Exception as e:
            logger.error(f"❌ Failed to get AI response: {e}")
            return NarrativeResponse(message="I'm sorry, I had a little trouble organizing my thoughts.")
        finally:
            stats.finish()
            logger.info(f"✅ Director response generated in {stats.processing_time_ms:.1f}ms")