import sys
from pathlib import Path
from unittest.mock import MagicMock

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))
import main


@pytest.fixture
def client():
    return main.app.test_client()


@pytest.fixture
def db_falsa(monkeypatch):
    conn = MagicMock()
    cursor = MagicMock()
    conn.cursor.return_value = cursor
    monkeypatch.setattr(main, "get_db_connection", lambda: conn)
    return cursor


def test_crear_tarea_regresa_201(client, db_falsa):
    db_falsa.fetchone.return_value = (1,)

    r = client.post("/tasks", json={"title": "estudiar para el examen", "done": False})

    assert r.status_code == 201
    assert r.get_json() == {"id": 1, "title": "estudiar para el examen", "done": False}


def test_crear_tarea_sin_title_regresa_400(client):
    r = client.post("/tasks", json={"done": False})

    assert r.status_code == 400
    assert r.get_json()["error"] == "el campo title es requerido"


def test_health_sin_base_de_datos_regresa_fail(client, monkeypatch):
    def falla():
        raise Exception("no hay conexion")

    monkeypatch.setattr(main, "get_db_connection", falla)

    r = client.get("/health")

    assert r.status_code == 503
    assert r.get_json()["database"] == "FAIL"
