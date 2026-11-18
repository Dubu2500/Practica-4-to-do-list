from flask import Flask, request, jsonify
from datetime import datetime, timezone
import boto3, json, os
import psycopg2

app = Flask(__name__)

REGION = os.environ.get("AWS_REGION", "us-east-1")
SECRET_NAME = os.environ.get("SECRET_NAME", "todo/db-credentials")
APP_VERSION = os.environ.get("APP_VERSION", "dev")
NAMESPACE = "TodoListApi"


def put_metric(name, value=1):
    try:
        cloudwatch = boto3.client("cloudwatch", region_name=REGION)
        cloudwatch.put_metric_data(
            Namespace=NAMESPACE,
            MetricData=[{"MetricName": name, "Value": value, "Unit": "Count"}],
        )
    except Exception as e:
        print(f"no se pudo enviar la metrica {name}: {e}")


def get_db_credentials():
    client = boto3.client("secretsmanager", region_name=REGION)
    response = client.get_secret_value(SecretId=SECRET_NAME)
    return json.loads(response["SecretString"])


def get_db_connection():
    creds = get_db_credentials()
    return psycopg2.connect(
        host=creds["host"],
        port=creds["port"],
        dbname=creds["dbname"],
        user=creds["username"],
        password=creds["password"],
        connect_timeout=5,
    )


def create_table():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "CREATE TABLE IF NOT EXISTS tasks (id SERIAL PRIMARY KEY, title TEXT NOT NULL, done BOOLEAN DEFAULT FALSE)"
    )
    conn.commit()
    cur.close()
    conn.close()


@app.route("/tasks", methods=["GET"])
def get_tasks():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, title, done FROM tasks ORDER BY id")
        rows = cur.fetchall()
        cur.close()
        conn.close()
    except Exception:
        put_metric("DBErrors")
        return jsonify({"error": "no se pudo leer de la base de datos"}), 500

    return jsonify([{"id": r[0], "title": r[1], "done": r[2]} for r in rows])


@app.route("/tasks", methods=["POST"])
def create_task():
    data = request.get_json()
    if not data or "title" not in data:
        return jsonify({"error": "el campo title es requerido"}), 400

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO tasks (title, done) VALUES (%s, %s) RETURNING id",
            (data["title"], data.get("done", False)),
        )
        task_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
    except Exception:
        put_metric("DBErrors")
        return jsonify({"error": "no se pudo escribir en la base de datos"}), 500

    put_metric("TasksCreated")
    return jsonify({"id": task_id, "title": data["title"], "done": data.get("done", False)}), 201


@app.route("/version", methods=["GET"])
def get_version():
    return jsonify({"version": APP_VERSION})


@app.route("/health", methods=["GET"])
def health():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        db = "OK"
    except Exception:
        put_metric("DBErrors")
        db = "FAIL"

    return jsonify({
        "database": db,
        "version": APP_VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }), 200 if db == "OK" else 503


if __name__ == "__main__":
    create_table()
    app.run(host="0.0.0.0", port=8000)
