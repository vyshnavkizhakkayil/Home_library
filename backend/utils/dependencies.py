from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from backend.database import get_db, set_app_user
from backend.utils.auth import SECRET_KEY, ALGORITHM
from backend.models.schemas import TokenData

# This tells FastAPI where the client should send username/password to get a token
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

def get_current_user(token: str = Depends(oauth2_scheme), db = Depends(get_db)):
    """
    Validates the JWT token from the Authorization header.
    Returns the user data and also sets the @app_current_user_id for database triggers.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Decode the token
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("username")
        user_id: int = payload.get("user_id")
        
        if username is None or user_id is None:
            raise credentials_exception
            
        token_data = TokenData(username=username, user_id=user_id)
    except JWTError:
        raise credentials_exception
        
    # Verify the user actually exists in DB
    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT id, username, role FROM users WHERE id = %s", (token_data.user_id,))
    user = cursor.fetchone()
    
    if user is None:
        cursor.close()
        raise credentials_exception
        
    # CRITICAL: Set the session variable so triggers can log the activity!
    set_app_user(cursor, user["id"])
    cursor.close()
    
    return user
