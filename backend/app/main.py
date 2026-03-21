"""
**Main Entrypoint**
Responsible for: Initializing the FastAPI application.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.api_v1.endpoints import chat, location, recommend, sensor
from app.api.crop_lgbm_api import router as crop_lgbm_router

app = FastAPI(
    title="Agri Scan Backend",
    version="1.0.0",
    description="Backend for AgriVora mobile application"
)

# Crucial for allowing your Flutter app to communicate with your backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register only the stable endpoints (Firebase & CNN disabled)
app.include_router(location.router, tags=["Location"])
app.include_router(recommend.router, tags=["Recommend"])
app.include_router(sensor.router, tags=["Sensor"])
app.include_router(chat.router, tags=["Chat"])
app.include_router(crop_lgbm_router)

@app.get("/")
def root():
    return {"message": "AgriVora backend is live"}

@app.get("/health")
def health_check():
    return {
        "success": True,
        "data": "Backend is running",
        "error": None
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)