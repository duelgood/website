from flask import Flask
import redis
import os

def read_secret(name):
    path = f"/run/secrets/{name}"
    try:
        with open(path) as f:
            return f.read().strip()
    except FileNotFoundError:
        return os.environ.get(name)

def create_app():
    app = Flask(__name__)
    
    # Configure Redis
    redis_host = os.environ.get("REDIS_HOST", "localhost")
    redis_port = int(os.environ.get("REDIS_PORT", 6379))
    
    app.redis_client = redis.Redis(
        host=redis_host,
        port=redis_port,
        decode_responses=True,
        socket_connect_timeout=5
    )
    
    # Register blueprints
    from . import routes
    app.register_blueprint(routes.bp)
    with app.app_context():
        from .routes import rebuild_stats_from_stripe
        try:
            rebuild_stats_from_stripe()
            print("Stats rebuilt from Stripe on startup")
        except Exception as e:
            print(f"Failed to rebuild stats on startup: {e}")
    
    return app