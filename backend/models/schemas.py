from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import date, datetime

# --- Auth Models ---
class UserCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    username: str = Field(..., min_length=3, max_length=50)
    password: str = Field(..., min_length=6)

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    username: Optional[str] = None
    user_id: Optional[int] = None

# --- Book Models ---
class BookCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    isbn: Optional[str] = None
    category_id: Optional[int] = None
    publisher: Optional[str] = None
    published_year: Optional[int] = None
    total_pages: Optional[int] = None
    language: str = "English"
    description: Optional[str] = None
    cover: Optional[str] = None
    author_ids: List[int] = []  # To link to the book_authors table

# --- Reading Session Models ---
class ReadingSessionCreate(BaseModel):
    user_books_id: int
    pages_read: int = Field(..., ge=0)
    started_at: datetime
    ended_at: Optional[datetime] = None
    notes: Optional[str] = None

# --- Wishlist Models ---
class WishlistCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    isbn: Optional[str] = None
    category_id: Optional[int] = None
    description: Optional[str] = None
    reason: Optional[str] = None
    priority: str = "medium"  # low, medium, high

# --- Borrowed Models ---
class BorrowedCreate(BaseModel):
    copy_id: Optional[int] = None
    direction: str = Field(..., description="lent or borrowed")
    person_name: str = Field(..., min_length=1, max_length=255)
    phone: Optional[str] = None
    due_date: Optional[date] = None
    notes: Optional[str] = None

# --- Author Models ---
class AuthorCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    nationality: Optional[str] = None
    bio: Optional[str] = None
    birth_date: Optional[date] = None
    death_date: Optional[date] = None
    image_url: Optional[str] = None
    website: Optional[str] = None

class AuthorResponse(AuthorCreate):
    id: int
    name_normalized: Optional[str] = None
    created_at: datetime

# --- Copy Models ---
class CopyCreate(BaseModel):
    copy_number: int = 1
    condition: str = "good"
    source: str = "purchased"
    acquired_date: Optional[date] = None
    notes: Optional[str] = None

class CopyResponse(CopyCreate):
    id: int
    book_id: int

# --- General Response Models ---
class BookResponse(BookCreate):
    id: int
    added_at: datetime

class ReadingSessionResponse(ReadingSessionCreate):
    id: int
    user_id: int
    created_at: datetime

class WishlistResponse(WishlistCreate):
    id: int
    user_id: int
    added_at: datetime

class BorrowedResponse(BorrowedCreate):
    id: int
    user_id: int
    borrow_date: date
    return_date: Optional[date] = None
