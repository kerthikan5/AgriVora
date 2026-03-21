from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="AgriVora Backend",
    version="1.0.0",
    description="Minimal health-check deployment"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {"message": "AgriVora backend is live"}

@app.get("/health")
def health():
    return {"status": "ok"}