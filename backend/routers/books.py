from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional
from backend.database import get_db
from backend.models.schemas import BookCreate, CopyCreate, CopyResponse
from backend.utils.dependencies import get_current_user
import httpx  # We need this to make external API calls to Google Books

router = APIRouter(prefix="/books", tags=["Books"])

@router.get("/")
def get_books(db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Get all books in the shared library, along with the current user's reading status.
    """
    cursor = db.cursor(dictionary=True)
    
    # We join books with user_books to see if the current user is reading them
    query = """
        SELECT b.id, b.title, b.isbn, b.total_pages, b.cover_image_url, 
               ub.status, ub.rating
        FROM books b
        LEFT JOIN user_books ub ON b.id = ub.book_id AND ub.user_id = %s
    """
    cursor.execute(query, (current_user['id'],))
    books = cursor.fetchall()
    cursor.close()
    
    return books

@router.post("/", status_code=status.HTTP_201_CREATED)
def add_book(book: BookCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Add a new book to the shared library.
    """
    cursor = db.cursor(dictionary=True)
    
    try:
        # Insert into books table
        query = """
            INSERT INTO books (title, isbn, category_id, publisher, published_year, total_pages, language, description)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """
        values = (book.title, book.isbn, book.category_id, book.publisher, 
                  book.published_year, book.total_pages, book.language, book.description)
        cursor.execute(query, values)
        new_book_id = cursor.lastrowid
        
        # Link authors in book_authors junction table
        for author_id in book.author_ids:
            cursor.execute("INSERT INTO book_authors (book_id, author_id) VALUES (%s, %s)", (new_book_id, author_id))
            
        db.commit()
        return {"message": "Book added successfully", "book_id": new_book_id}
        
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {e}")
    finally:
        cursor.close()

@router.get("/isbn/{isbn}")
async def lookup_isbn(isbn: str, current_user=Depends(get_current_user)):
    """
    Fetch book details from Google Books API using an ISBN.
    """
    # For now, we will use the free Google Books API volume endpoint without a key for basic lookups.
    url = f"https://www.googleapis.com/books/v1/volumes?q=isbn:{isbn}"
    
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        data = response.json()
        
    if "items" not in data or len(data["items"]) == 0:
        raise HTTPException(status_code=404, detail="Book not found via ISBN")
        
    book_info = data["items"][0]["volumeInfo"]
    
    # Extract useful data to return to the Android app so it can pre-fill the form
    return {
        "title": book_info.get("title", ""),
        "authors": book_info.get("authors", []),
        "publisher": book_info.get("publisher", ""),
        "published_year": book_info.get("publishedDate", "")[:4] if book_info.get("publishedDate") else None,
        "total_pages": book_info.get("pageCount", None),
        "description": book_info.get("description", ""),
        "cover_image_url": book_info.get("imageLinks", {}).get("thumbnail", "")
    }

@router.get("/{book_id}/copies", response_model=List[CopyResponse])
def get_book_copies(book_id: int, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Get all physical copies for a specific book.
    """
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT * FROM copies WHERE book_id = %s", (book_id,))
    copies = cursor.fetchall()
    cursor.close()
    return copies

@router.post("/{book_id}/copies", status_code=status.HTTP_201_CREATED, response_model=CopyResponse)
def add_book_copy(book_id: int, copy: CopyCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Add a new physical copy of a book.
    """
    cursor = db.cursor(dictionary=True)
    try:
        # Verify book exists
        cursor.execute("SELECT id FROM books WHERE id = %s", (book_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Book not found")
            
        query = """
            INSERT INTO copies (book_id, copy_number, `condition`, source, acquired_date, notes)
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        values = (book_id, copy.copy_number, copy.condition, copy.source, copy.acquired_date, copy.notes)
        cursor.execute(query, values)
        db.commit()
        
        new_copy_id = cursor.lastrowid
        cursor.execute("SELECT * FROM copies WHERE id = %s", (new_copy_id,))
        new_copy = cursor.fetchone()
        return new_copy
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {e}")
    finally:
        cursor.close()
