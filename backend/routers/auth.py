from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from mysql.connector import Error
from backend.database import get_db
from backend.models.schemas import UserCreate, Token
from backend.utils.auth import get_password_hash, verify_password, create_access_token

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register_user(user: UserCreate, db=Depends(get_db)):
    """
    Register a new user in the system.
    Returns a JWT access token upon successful registration.
    """
    cursor = db.cursor(dictionary=True)
    
    # 1. Check if username already exists
    cursor.execute("SELECT id FROM users WHERE username = %s", (user.username,))
    if cursor.fetchone():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )
        
    # 2. Hash the password securely
    hashed_password = get_password_hash(user.password)
    
    # 3. Insert into the database
    try:
        # Note: We don't need set_app_user() here because the user doesn't exist yet,
        # so they can't be logged in while registering themselves.
        cursor.execute(
            "INSERT INTO users (name, username, password_hash, role) VALUES (%s, %s, %s, %s)",
            (user.name, user.username, hashed_password, 'member')
        )
        db.commit()
        new_user_id = cursor.lastrowid
        
        # 4. Generate login token automatically so they don't have to log in immediately
        access_token = create_access_token(data={"user_id": new_user_id, "username": user.username})
        return {"access_token": access_token, "token_type": "bearer"}
        
    except Error as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error during registration: {e}"
        )
    finally:
        cursor.close()


@router.post("/login", response_model=Token)
def login_user(form_data: OAuth2PasswordRequestForm = Depends(), db=Depends(get_db)):
    """
    Authenticate user and return a JWT access token.
    Uses standard OAuth2 password request form (username and password).
    """
    cursor = db.cursor(dictionary=True)
    
    # 1. Fetch user by username
    cursor.execute("SELECT id, username, password_hash FROM users WHERE username = %s", (form_data.username,))
    user = cursor.fetchone()
    cursor.close()
    
    # 2. Verify existence and password
    if not user or not verify_password(form_data.password, user['password_hash']):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    # 3. Generate JWT token
    access_token = create_access_token(data={"user_id": user['id'], "username": user['username']})
    return {"access_token": access_token, "token_type": "bearer"}
