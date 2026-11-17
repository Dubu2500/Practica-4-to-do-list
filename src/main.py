from flask import Flask, request, jsonify

app = Flask(__name__)

tasks = []


@app.route("/tasks", methods=["GET"])
def get_tasks():
    return jsonify(tasks)


@app.route("/tasks", methods=["POST"])
def create_task():
    data = request.get_json()
    if not data or "title" not in data:
        return jsonify({"error": "el campo title es requerido"}), 400

    task = {
        "id": len(tasks) + 1,
        "title": data["title"],
        "done": data.get("done", False),
    }
    tasks.append(task)
    return jsonify(task), 201


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
