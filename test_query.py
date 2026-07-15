from backend.database import get_db_connection
conn = get_db_connection()
if conn:
    print(f"Is connected: {conn.is_connected()}")
    try:
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT 1")
        print(cursor.fetchall())
    except Exception as e:
        print(e)
else:
    print("Failed to get conn")
