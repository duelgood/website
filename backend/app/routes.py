from flask import Blueprint, request, jsonify, redirect, render_template
from . import db
from .models import Donation
from datetime import datetime, timezone
from email_validator import validate_email, EmailNotValidError
from sqlalchemy import extract

bp = Blueprint("api", __name__, url_prefix="/api")

@bp.route("/stats", methods=["GET"])
def get_stats():
    now = datetime.now(timezone.utc)

    total = db.session.query(db.func.sum(Donation.amount)).scalar() or 0
    count = db.session.query(db.func.count(Donation.id)).scalar() or 0

    month_amount = db.session.query(db.func.sum(Donation.amount))\
        .filter(extract('year', Donation.time) == now.year)\
        .filter(extract('month', Donation.time) == now.month)\
        .scalar() or 0

    # https://www.givewell.org/how-much-does-it-cost-to-save-a-life
    lives_saved = int(float(total) / 3000)
    lives_saved_month = int(float(month_amount) / 3000)

    a_total = db.session.query(db.func.sum(Donation.amount))\
        .filter(Donation.cause == 'a')\
        .scalar() or 0
    b_total = db.session.query(db.func.sum(Donation.amount))\
        .filter(Donation.cause == 'b')\
        .scalar() or 0
    

    # need to add top donors and state data
    # we need a way to associate all the donations 
    # that a given donor has ever made with that donor
    # we probably need to update our schema, or just 
    # allow one-time donations? but recurring donations 
    # are far more effective. 

    return jsonify({
        "total_amount": float(total),
        "month_amount": float(month_amount),
        "lives_saved": lives_saved,
        "lives_saved_month": lives_saved_month,
        "a": float(a_total),
        "b": float(b_total)
    })

# list recent donations
@bp.route("/donations", methods=["GET"])
def list_donations():
    donations = Donation.query.order_by(Donation.time.desc()).limit(20).all()
    return jsonify([
        {
            "id": d.id,
            "amount": float(d.amount),
            "display_name": d.display_name,
            "time": d.time.isoformat()
        }
        for d in donations
    ])


@bp.route("/donations", methods=["POST"])
def api_donate():
    """
    Accept form POSTs from /pages/donate.shtml. Expects form fields:
    amount, type, cause, display_name, email, legal_name, street, city, state, zip,
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

        cause = form.get('cause')
        donor_name = form.get('legal_name')

        raw_email = (form.get('email') or '').strip()
        try:
            v = validate_email(raw_email)
            # normalized (lowercased, etc.)
            email = v.email 
        except EmailNotValidError as e:
            return jsonify({'error': f'{raw_email} is an invalid email address'}), 400
        
        street_address = form.get('street_address', '').strip()
        city = form.get('city', '').strip()
        state = (form.get('state') or '').strip().upper()
        zip_code = form.get('zip', '').strip()
        display_name = form.get('display_name') or 'Anonymous'
        timestamp = form.get('timestamp')
        if timestamp:
            try:
                time_val = datetime.fromisoformat(timestamp.replace('Z','+00:00'))
            except Exception:
                time_val = datetime.now(timezone.utc)
        else:
            time_val = datetime.now(timezone.utc)

        required = [cause, donor_name, email, street_address, city, state, zip_code]
        if not all(required):
            return jsonify({'error': 'Missing required fields'}), 400

        donation = Donation(
            time=time_val,
            amount=amount,
            display_name=display_name,
            cause=cause,
            donor_name=donor_name,
            email=email,
            street_address=street_address,
            city=city,
            state=state,
            zip_code=zip_code
        )
        db.session.add(donation)
        db.session.commit() 

        return redirect(f'https://duelgood.org/thank-you?cause={cause}', code=302)
    except Exception as e:
        db.session.rollback()
        # keep server logs for debugging
        print('Error in /api/donate:', e)
        return jsonify({'error': e}), 500

@bp.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200

@bp.route("/thank-you")
def thank_you():
    cause = request.args.get('cause', 'unknown')
    
    # Define cause-specific content
    cause_messages = {
        'a': {
            'message': 'Your donation will help us advance cause A.'
        },
        'b': {
            'message': 'Your donation will help us advance cause B'
        }
    }
    
    content = cause_messages.get(cause, {
        'message': 'Your contribution makes a difference.'
    })
    
    return render_template('thank-you.shtml', **content)