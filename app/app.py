from flask import Flask, Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

REQUEST_COUNT = Counter("request_count", "Total HTTP requests", ["endpoint"])


@app.route("/")
def index():
    REQUEST_COUNT.labels("/").inc()
    return "Hello from Azure AKS DevOps demo!\n"


@app.route("/healthz")
def healthz():
    return "ok", 200


@app.route("/metrics")
def metrics():
    data = generate_latest()
    return Response(data, mimetype=CONTENT_TYPE_LATEST)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
