from flask import Flask
import redis
import os
import logging

def read_secret(name):
    path = f"/run/secrets/{name}"
    try:
        with open(path) as f:
            return f.read().strip()
    except FileNotFoundError:
        return os.environ.get(name)

def create_app():
    app = Flask(__name__)

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers = [
            logging.StreamHandler()
        ]
    )
    logger = logging.getLogger(__name__)
    
    redis_host = os.environ.get("REDIS_HOST", "127.0.0.1")
    redis_port = int(os.environ.get("REDIS_PORT", 6379))
    redis_password = read_secret("redis_password")

    if not redis_password:
        raise RuntimeError("Redis password not configured")

    app.redis_client = redis.Redis(
        host=redis_host,
        port=redis_port,
        decode_responses=True,
        socket_connect_timeout=5,
        password=redis_password,
    )
    
    from . import routes
    app.register_blueprint(routes.bp)
    with app.app_context():
        try:
            routes.rebuild_stats_from_stripe()
            logger.info("Stats rebuilt from Stripe on startup")
        except Exception as e:
            logger.error(f"Failed to rebuild stats on startup: {e}")
    
    return app