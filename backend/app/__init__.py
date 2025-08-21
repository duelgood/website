from flask import Flask, jsonify, request, render_template
from flask_sqlalchemy import SQLAlchemy
import os
from datetime import datetime
import click
from flask.cli import with_appcontext

db = SQLAlchemy()

def create_app():
    app = Flask(__name__)

    # Database config
    app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv("DATABASE_URL")
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    db.init_app(app)

    # Import models
    from .models import Donation
    
    # Import and register routes blueprint
    from .routes import bp as api_bp
    app.register_blueprint(api_bp)

    @app.cli.command("db-init")
    @with_appcontext
    def db_init():
        """Initialize the database (create tables)."""
        db.create_all()
        click.echo("Database initialized.")

    return app