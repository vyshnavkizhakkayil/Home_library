from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from backend.database import get_db, set_app_user
from backend.models.schemas import BorrowedCreate, BorrowedResponse
from backend.utils.dependencies import get_current_user

router = APIRouter(prefix="/borrowed", tags=["Borrowed"])

@router.get("/", response_model=List[BorrowedResponse])
def get_borrowed(db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Get all borrowed/lent items for the current user.
    """
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT * FROM borrowed WHERE user_id = %s", (current_user['id'],))
    borrowed_items = cursor.fetchall()
    cursor.close()
    return borrowed_items

@router.post("/", status_code=status.HTTP_201_CREATED, response_model=BorrowedResponse)
def add_borrowed(item: BorrowedCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Add a new borrowed/lent record.
    """
    cursor = db.cursor(dictionary=True)
    try:
        set_app_user(cursor, current_user['id'])
        
        query = """
            INSERT INTO borrowed (user_id, copy_id, direction, person_name, phone, due_date, notes)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        values = (current_user['id'], item.copy_id, item.direction, item.person_name, 
                  item.phone, item.due_date, item.notes)
        cursor.execute(query, values)
        db.commit()
        
        new_id = cursor.lastrowid
        cursor.execute("SELECT * FROM borrowed WHERE id = %s", (new_id,))
        new_item = cursor.fetchone()
        return new_item
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {e}")
    finally:
        cursor.close()

@router.put("/{item_id}/return", response_model=BorrowedResponse)
def return_borrowed(item_id: int, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Mark a borrowed item as returned.
    """
    cursor = db.cursor(dictionary=True)
    try:
        set_app_user(cursor, current_user['id'])
        
        cursor.execute("SELECT id FROM borrowed WHERE id = %s AND user_id = %s", (item_id, current_user['id']))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Borrowed record not found or not owned by user")
            
        cursor.execute("UPDATE borrowed SET return_date = CURRENT_DATE WHERE id = %s", (item_id,))
        db.commit()
        
        cursor.execute("SELECT * FROM borrowed WHERE id = %s", (item_id,))
        updated_item = cursor.fetchone()
        return updated_item
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {e}")
    finally:
        cursor.close()
