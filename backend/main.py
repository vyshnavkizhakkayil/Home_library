from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os

from backend.routers import auth, books, authors, borrowed, wishlist, reading_sessions

app = FastAPI(
    title="Home Library API",
    description="Backend for the Home Library Android Application",
    version="1.0.0"
)

# CORS middleware to allow requests from our Android app (or any web frontend we build)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, you would restrict this to specific domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include the routers we just built
app.include_router(auth.router)
app.include_router(books.router)
app.include_router(authors.router)
app.include_router(borrowed.router)
app.include_router(wishlist.router)
app.include_router(reading_sessions.router)

# Serve the static images folder so the Android app can fetch book covers
images_path = os.path.join(os.path.dirname(__file__), '..', 'images')
app.mount("/images", StaticFiles(directory=images_path), name="images")

@app.get("/")
def root():
    return {"message": "Welcome to the Home Library API. Go to /docs for the Swagger UI."}
