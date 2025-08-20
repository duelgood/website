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

    @app.route("/health")
    def health():
        return {"status": "ok"}

    @app.route('/donate', methods=['POST'])
    def handle_donation():
        try:
            # Get form data
            amount = float(request.form.get('amount'))
            display_name = request.form.get('display_name') or 'Anonymous'
            party = request.form.get('party')
            donation_type = request.form.get('type', 'one-time')
            donor_name = request.form.get('legal_name')
            email = request.form.get('email')
            mailing_address = request.form.get('mailing_address')
            employer = request.form.get('employer')
            occupation = request.form.get('occupation')
            
            # Validate required fields
            if not all([amount, party, donor_name, email, mailing_address, employer, occupation]):
                return jsonify({'error': 'Missing required fields'}), 400
            
            if amount < 1:
                return jsonify({'error': 'Minimum donation is $1'}), 400
            
            # Create donation record
            donation = Donation(
                time=datetime.utcnow(),
                amount=amount,
                display_name=display_name,
                party=party,
                donation_type=donation_type,
                donor_name=donor_name,
                email=email,
                mailing_address=mailing_address,
                employer=employer,
                occupation=occupation
            )
            
            db.session.add(donation)
            db.session.commit()
            
            return jsonify({'success': True, 'id': donation.id})
            
        except ValueError:
            return jsonify({'error': 'Invalid amount'}), 400
        except Exception as e:
            db.session.rollback()
            print(f"Error saving donation: {str(e)}")
            return jsonify({'error': 'Database error'}), 500

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