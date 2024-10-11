from flask import Flask, jsonify
import psycopg2

app = Flask(__name__)

@app.route('/hello', methods=['GET'])
def hello_world():
    return jsonify(message="Hello, World!")

@app.route('/data', methods=['GET'])
def get_data():
    conn = psycopg2.connect(
        dbname='mydb',
        user='admin',
        password='your_db_password',
        host='your_db_host',
        port='5432'
    )
    cur = conn.cursor()
    cur.execute("SELECT * FROM your_table")
    data = cur.fetchall()
    conn.close()
    return jsonify(data)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
