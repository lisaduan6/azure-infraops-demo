from app.app import app


def test_root_returns_200():
    client = app.test_client()
    resp = client.get("/")
    assert resp.status_code == 200
    assert b"Hello" in resp.data
