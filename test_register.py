from backend.database import get_db
from backend.routers.auth import register_user
from backend.models.schemas import UserCreate
import traceback

user = UserCreate(name="Test User", username="testuser3", password="password123")
try:
    db = next(get_db())
    res = register_user(user=user, db=db)
    print(res)
except Exception as e:
    print("ERROR:")
    traceback.print_exc()
