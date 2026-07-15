import mysql.connector
try:
    connection = mysql.connector.connect(host="localhost", port=3307, user="root", password="1May@2004", database="home_library")
    print("Success root")
except Exception as e:
    print(e)
