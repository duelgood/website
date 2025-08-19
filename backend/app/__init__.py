from flask import Flask, jsonify, request
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

    @app.route("/health")
    def health():
        return {"status": "ok"}

    @app.route("/donations", methods=["POST"])
    def add_donation():
        data = request.json
        donation = Donation(
            time=datetime.utcnow(),
            amount=data["amount"],
            display_name=data.get("display_name"),
            party=data.get("party"),
            donor_name=data.get("donor_name"),
            mailing_address=data.get("mailing_address"),
            employer=data.get("employer"),
            occupation=data.get("occupation"),
        )
        db.session.add(donation)
        db.session.commit()
        return {"message": "Donation added"}, 201

    @app.route("/stats", methods=["GET"])
    def get_stats():
        total = db.session.query(db.func.sum(Donation.amount)).scalar() or 0
        count = db.session.query(db.func.count(Donation.id)).scalar() or 0
        return {
            "total_amount": float(total),
            "donation_count": count
        }

    @app.cli.command("db-init")
    @with_appcontext
    def db_init():
        """Initialize the database (create tables)."""
        db.create_all()
        click.echo("Database initialized.")

    return app