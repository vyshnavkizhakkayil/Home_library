from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from datetime import datetime
from backend.database import get_db, set_app_user
from backend.models.schemas import ReadingSessionCreate, ReadingSessionResponse
from backend.utils.dependencies import get_current_user

router = APIRouter(prefix="/reading_sessions", tags=["Reading Sessions"])

@router.get("/", response_model=List[ReadingSessionResponse])
def get_reading_sessions(db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Get all reading sessions for the current user.
    """
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT * FROM reading_sessions WHERE user_id = %s", (current_user['id'],))
    sessions = cursor.fetchall()
    cursor.close()
    return sessions

@router.post("/", status_code=status.HTTP_201_CREATED, response_model=ReadingSessionResponse)
def add_reading_session(session: ReadingSessionCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Start or log a reading session.
    """
    cursor = db.cursor(dictionary=True)
    try:
        set_app_user(cursor, current_user['id'])
        
        # Check if user_books_id belongs to the current user
        cursor.execute("SELECT id FROM user_books WHERE id = %s AND user_id = %s", 
                       (session.user_books_id, current_user['id']))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="User book record not found")
            
        query = """
            INSERT INTO reading_sessions (user_books_id, user_id, pages_read, started_at, ended_at, notes)
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        values = (session.user_books_id, current_user['id'], session.pages_read, 
                  session.started_at, session.ended_at, session.notes)
        cursor.execute(query, values)
        db.commit()
        
        new_id = cursor.lastrowid
        cursor.execute("SELECT * FROM reading_sessions WHERE id = %s", (new_id,))
        new_session = cursor.fetchone()
        return new_session
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {e}")
    finally:
        cursor.close()

@router.put("/{session_id}/end", response_model=ReadingSessionResponse)
def end_reading_session(session_id: int, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    End an active reading session by setting ended_at to now.
    """
    cursor = db.cursor(dictionary=True)
    try:
        set_app_user(cursor, current_user['id'])
        
        cursor.execute("SELECT id FROM reading_sessions WHERE id = %s AND user_id = %s", 
                       (session_id, current_user['id']))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Reading session not found or not owned by user")
            
        now = datetime.now()
        cursor.execute("UPDATE reading_sessions SET ended_at = %s WHERE id = %s AND ended_at IS NULL", 
                       (now, session_id))
        db.commit()
        
        cursor.execute("SELECT * FROM reading_sessions WHERE id = %s", (session_id,))
        updated_session = cursor.fetchone()
        return updated_session
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {e}")
    finally:
        cursor.close()
