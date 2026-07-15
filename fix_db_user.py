import mysql.connector
try:
    connection = mysql.connector.connect(host="localhost", port=3307, user="root", password="1May@2004")
    cursor = connection.cursor()
    cursor.execute("CREATE USER IF NOT EXISTS 'home_library_user'@'%' IDENTIFIED BY 'home_library_pass'")
    cursor.execute("GRANT ALL PRIVILEGES ON home_library.* TO 'home_library_user'@'%'")
    cursor.execute("FLUSH PRIVILEGES")
    connection.commit()
    print("User fixed")
except Exception as e:
    print(e)
