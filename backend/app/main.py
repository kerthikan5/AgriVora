"""
**Main Entrypoint**
Responsible for: Initializing the FastAPI application.
Role: Mounts CORS middleware and includes all routers (auth, user, images, location, recommend, sensor).
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.api_v1.endpoints import (auth, chat, history, image, location,
                                      recommend, sensor, user)
from app.api.crop_lgbm_api import router as crop_lgbm_router
from app.api.soil_cnn import router as soil_cnn_router

# Step 1: Initialize the core FastAPI application with metadata
app = FastAPI(
    title="Agri Scan Backend",
    version="1.0.0",
    description="Backend for AgriVora mobile application"
)

# Step 2: Configure CORS middleware to accept connections from the Flutter frontend
app.add_middleware( 
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Step 3: Register standard feature routers (Location, Image Processing, Recommend, History, Sensor IoT, Chat AI)
app.include_router(location.router, tags=["Location"])
app.include_router(image.router, tags=["Image"])
app.include_router(recommend.router, tags=["Recommend"])
app.include_router(history.router, tags=["History"])
app.include_router(sensor.router, tags=["Sensor"])
app.include_router(chat.router, tags=["Chat"])

# Step 4: Register specific Machine Learning Model routers
app.include_router(soil_cnn_router)
app.include_router(crop_lgbm_router)

# Step 5: Register authentication and user management routers with specific base path prefixes
app.include_router(user.router, prefix="/api/users", tags=["Users"])
app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])

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
