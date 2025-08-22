from flask import Flask, jsonify, request, render_template
from flask_sqlalchemy import SQLAlchemy
import os
from datetime import datetime
import click
from flask.cli import with_appcontext
from flask_migrate import Migrate, upgrade

db = SQLAlchemy()
migrate = Migrate()

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
        """Initialize DB if not exists, then apply migrations."""
        from sqlalchemy_utils import database_exists, create_database
        uri = app.config["SQLALCHEMY_DATABASE_URI"]

        if not database_exists(uri):
            create_database(uri)
            click.echo("Database created.")

        upgrade()
        click.echo("Database schema is up to date.")


    migrate.init_app(app, db)
    return app