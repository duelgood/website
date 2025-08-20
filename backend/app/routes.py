from flask import Blueprint, request, jsonify
from . import db
from .models import Donation
from datetime import datetime

bp = Blueprint("api", __name__, url_prefix="/api")

@bp.route("/donate", methods=["POST"])
def api_donate():
    """
    Accept form POSTs from /pages/donate.shtml. Expects form fields:
    amount, type, party, display_name, email, legal_name, street, city, state, zip,
    employer, occupation, optional timestamp.
    """
    try:
        form = request.form
        # parse and validate
        try:
            amount = float(form.get('amount') or 0)
        except ValueError:
            return jsonify({'error': 'Invalid amount'}), 400

        if amount < 1:
            return jsonify({'error': 'Minimum donation is $1'}), 400

        party = form.get('party')
        donor_name = form.get('legal_name')
        email = form.get('email')
        street = form.get('street', '').strip()
        city = form.get('city', '').strip()
        state = (form.get('state') or '').strip().upper()
        zip_code = form.get('zip', '').strip()
        mailing_address = form.get('mailing_address') or f"{street}\n{city}, {state} {zip_code}"
        employer = form.get('employer')
        occupation = form.get('occupation')
        display_name = form.get('display_name') or 'Anonymous'
        donation_type = form.get('type') or 'one-time'
        timestamp = form.get('timestamp')
        if timestamp:
            try:
                time_val = datetime.fromisoformat(timestamp.replace('Z','+00:00'))
            except Exception:
                time_val = datetime.utcnow()
        else:
            time_val = datetime.utcnow()

        required = [party, donor_name, email, mailing_address, employer, occupation]
        if not all(required):
            return jsonify({'error': 'Missing required fields'}), 400

        donation = Donation(
            time=time_val,
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
        return jsonify({'success': True, 'id': donation.id}), 201
    except Exception as e:
        db.session.rollback()
        # keep server logs for debugging
        print('Error in /api/donate:', e)
        return jsonify({'error': 'Server error'}), 500