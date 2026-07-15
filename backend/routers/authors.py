from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from backend.database import get_db
from backend.models.schemas import AuthorCreate, AuthorResponse
from backend.utils.dependencies import get_current_user

router = APIRouter(prefix="/authors", tags=["Authors"])

@router.get("/", response_model=List[AuthorResponse])
def get_authors(db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Get all authors in the shared library.
    """
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT * FROM authors")
    authors = cursor.fetchall()
    cursor.close()
    return authors

@router.post("/", status_code=status.HTTP_201_CREATED, response_model=AuthorResponse)
def add_author(author: AuthorCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Add a new author.
    """
    cursor = db.cursor(dictionary=True)
    try:
        # Normalize name for duplicate detection (simple lowercase)
        name_normalized = author.name.lower().strip()
        
        query = """
            INSERT INTO authors (name, name_normalized, nationality, bio, birth_date, death_date, image_url, website)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        values = (author.name, name_normalized, author.nationality, author.bio, 
                  author.birth_date, author.death_date, author.image_url, author.website)
        cursor.execute(query, values)
        db.commit()
        
        new_author_id = cursor.lastrowid
        cursor.execute("SELECT * FROM authors WHERE id = %s", (new_author_id,))
        new_author = cursor.fetchone()
        return new_author
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {e}")
    finally:
        cursor.close()

@router.get("/{author_id}", response_model=AuthorResponse)
def get_author(author_id: int, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Get a specific author by ID.
    """
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT * FROM authors WHERE id = %s", (author_id,))
    author = cursor.fetchone()
    cursor.close()
    
    if not author:
        raise HTTPException(status_code=404, detail="Author not found")
        
    return author
