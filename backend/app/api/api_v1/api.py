from fastapi import APIRouter

from app.api.api_v1.endpoints import (auth, history, image, location,
                                      recommend, sensor, user)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(user.router, prefix="/users", tags=["Users"])
api_router.include_router(history.router, prefix="/history", tags=["History"])
api_router.include_router(image.router, prefix="/image", tags=["Image"])
api_router.include_router(location.router, prefix="/location", tags=["Location"])
api_router.include_router(recommend.router, prefix="/recommend", tags=["Recommend"])
api_router.include_router(sensor.router, prefix="/sensor", tags=["Sensor"])
