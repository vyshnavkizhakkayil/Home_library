from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from backend.database import get_db, set_app_user
from backend.models.schemas import WishlistCreate, WishlistResponse
from backend.utils.dependencies import get_current_user

router = APIRouter(prefix="/wishlist", tags=["Wishlist"])

@router.get("/", response_model=List[WishlistResponse])
def get_wishlist(db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Get the current user's wishlist.
    """
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT * FROM wishlist WHERE user_id = %s", (current_user['id'],))
    items = cursor.fetchall()
    cursor.close()
    return items

@router.post("/", status_code=status.HTTP_201_CREATED, response_model=WishlistResponse)
def add_to_wishlist(item: WishlistCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Add a new book to the wishlist.
    """
    cursor = db.cursor(dictionary=True)
    try:
        set_app_user(cursor, current_user['id'])
        
        query = """
            INSERT INTO wishlist (user_id, title, isbn, category_id, description, reason, priority)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        values = (current_user['id'], item.title, item.isbn, item.category_id, 
                  item.description, item.reason, item.priority)
        cursor.execute(query, values)
        db.commit()
        
        new_id = cursor.lastrowid
        cursor.execute("SELECT * FROM wishlist WHERE id = %s", (new_id,))
        new_item = cursor.fetchone()
        return new_item
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {e}")
    finally:
        cursor.close()

@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_from_wishlist(item_id: int, db=Depends(get_db), current_user=Depends(get_current_user)):
    """
    Remove a book from the wishlist.
    """
    cursor = db.cursor(dictionary=True)
    try:
        set_app_user(cursor, current_user['id'])
        
        cursor.execute("SELECT id FROM wishlist WHERE id = %s AND user_id = %s", (item_id, current_user['id']))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Wishlist item not found or not owned by user")
            
        cursor.execute("DELETE FROM wishlist WHERE id = %s", (item_id,))
        db.commit()
        
        return None
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database Error: {e}")
    finally:
        cursor.close()
