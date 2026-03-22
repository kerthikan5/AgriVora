"""
**Chat AI Endpoint**
Responsible for: Handling conversational questions using an LLM.
"""

import os

from dotenv import load_dotenv
from fastapi import APIRouter
from openai import OpenAI
from pydantic import BaseModel

load_dotenv(override=True)

router = APIRouter()

# Initialize OpenAI client
# It's better to do this inside the function if you want to handle missing API key gracefully during startup
# or just ensure it's in .env

class ChatRequest(BaseModel):
    message: str

@router.post("/chat")
async def chat_with_ai(data: ChatRequest):
    api_key = os.getenv("OPENAI_API_KEY")
    system_prompt = "You are AgriVora AI, a highly specialized agricultural expert. You help farmers optimize their crop yields, analyze soil health, and provide sustainable farming practices. Be professional, encouraging, and provide specific, actionable advice."

    if api_key and api_key.strip():
        try:
            client = OpenAI(api_key=api_key)
            response = client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": data.message}
                ],
                max_tokens=500,
                temperature=0.7
            )
            return {"success": True, "data": {"reply": response.choices[0].message.content}, "error": None}
        except Exception as e:
            error_msg = str(e)
            if "insufficient_quota" in error_msg or "invalid_api_key" in error_msg or "Incorrect API key" in error_msg:
                # Flow down to the free alternative
                pass
            else:
                return {"success": False, "data": None, "error": error_msg}

    # Free GPT Alternative Pipeline
    try:
        import shutil
        from pathlib import Path

        # Clear local g4f scraper disk caches to prevent ENOSPC (no space left)
        g4f_cache_path = Path.home() / ".cache" / "g4f"
        if g4f_cache_path.exists():
            shutil.rmtree(str(g4f_cache_path), ignore_errors=True)

        from g4f.client import Client as FreeClient
        from g4f.Provider import PollinationsAI
        
        free_client = FreeClient()
        response = free_client.chat.completions.create(
            model="openai",
            provider=PollinationsAI,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": data.message}
            ]
        )
        reply_content = response.choices[0].message.content
        return {"success": True, "data": {"reply": reply_content}, "error": None}
    except Exception as e:
        # Avoid presenting raw disk errors inside chat UI
        return {
            "success": False, 
            "data": None, 
            "error": "The AI assistant is temporarily unavailable. Please try again shortly."
        }
