import os
import mysql.connector
from mysql.connector import Error
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '..', '.env'))

def get_db_connection():
    """
    Creates and returns a connection to the MySQL database.
    """
    try:
        connection = mysql.connector.connect(
            host="localhost", # In development, we access it via localhost on the mapped port
            port=3307,        # The port we mapped in docker-compose.yml
            user=os.getenv("MYSQL_USER", "home_library_user"),
            password=os.getenv("MYSQL_PASSWORD", "home_library_pass"),
            database=os.getenv("MYSQL_DATABASE", "home_library")
        )
        if connection.is_connected():
            return connection
    except Error as e:
        print(f"Error while connecting to MySQL: {e}")
        return None

def get_db():
    """
    Dependency function for FastAPI to get the database connection.
    Yields the connection and closes it when the request is done.
    """
    conn = get_db_connection()
    if not conn:
        raise Exception("Database connection failed")
    
    try:
        yield conn
    finally:
        if conn.is_connected():
            conn.close()

def set_app_user(cursor, user_id: int):
    """
    Sets the @app_current_user_id session variable for the triggers.
    This MUST be called on the connection before any INSERT/UPDATE/DELETE.
    """
    cursor.execute(f"SET @app_current_user_id = {user_id};")
