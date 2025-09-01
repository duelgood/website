from flask import Flask, jsonify, request, render_template
from flask_sqlalchemy import SQLAlchemy
import os
from datetime import datetime
import click
from flask.cli import with_appcontext
from flask_migrate import Migrate, upgrade
from sqlalchemy_utils import database_exists, create_database
# from jinja2 import FileSystemLoader

db = SQLAlchemy()
migrate = Migrate()

def create_app():
    app = Flask(__name__)
    '''
    app.jinja_loader = FileSystemLoader([
        os.path.join(os.path.dirname(__file__), '../../pages'),  
        os.path.join(os.path.dirname(__file__), 'templates') 
    ])
    app.jinja_env.add_extension('jinja2.ext.do')
    '''

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
        uri = app.config["SQLALCHEMY_DATABASE_URI"]

        if not database_exists(uri):
            create_database(uri)
            click.echo("Database created.")

        upgrade()
        click.echo("Database schema is up to date.")


    migrate.init_app(app, db)
    return app