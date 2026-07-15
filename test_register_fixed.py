from backend.database import get_db
from backend.routers.auth import register_user
from backend.models.schemas import UserCreate
import traceback

user = UserCreate(name="Test User", username="testuser4", password="password123")
gen = get_db()
db = next(gen)
try:
    res = register_user(user=user, db=db)
    print("Success:", res)
except Exception as e:
    print("ERROR:")
    traceback.print_exc()
finally:
    try:
        next(gen)
    except StopIteration:
        pass
