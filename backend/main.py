import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.firebase import get_firebase_app
from src.routers.api_router import router


@asynccontextmanager
async def lifespan(app: FastAPI):
    get_firebase_app()
    yield


app = FastAPI(title="Agapay API", lifespan=lifespan)

_raw_origins = os.getenv("CORS_ORIGINS", "*")
_origins = [o.strip() for o in _raw_origins.split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)


@app.get("/")
def health_check() -> dict[str, str]:
    return {"status": "ok"}
