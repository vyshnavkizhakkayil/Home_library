from backend.database import get_db_connection
conn = get_db_connection()
if conn:
    print("Success")
else:
    print("Failed")
