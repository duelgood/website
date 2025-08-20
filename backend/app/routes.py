from flask import Blueprint, jsonify
from sqlalchemy import func, extract
from datetime import datetime, timezone
from . import db
from .models import Donation

bp = Blueprint("api", __name__, url_prefix="/api")

@bp.route("/stats")
def stats():
    now = datetime.now(timezone.utc)
    
    # Total donated
    total_amount = db.session.query(func.sum(Donation.amount)).scalar() or 0

    # Donated this month
    month_amount = db.session.query(func.sum(Donation.amount))\
        .filter(extract('year', Donation.time) == now.year)\
        .filter(extract('month', Donation.time) == now.month)\
        .scalar() or 0

    # Lives saved: https://www.givewell.org/how-much-does-it-cost-to-save-a-life
    lives_saved = int(total_amount / 3000)
    lives_saved_month = int(month_amount / 3000)

    # Donations by cause (using correct party values)
    cause_a = db.session.query(func.sum(Donation.amount))\
        .filter(Donation.party == "democrat").scalar() or 0
    cause_b = db.session.query(func.sum(Donation.amount))\
        .filter(Donation.party == "republican").scalar() or 0

    # Top donors (sum per display_name, top 10)
    top_query = db.session.query(
        Donation.display_name,
        func.sum(Donation.amount).label("total")
    ).group_by(Donation.display_name)\
     .order_by(func.sum(Donation.amount).desc())\
     .limit(10).all()
    top_donors = [{"donor": r[0], "amount": float(r[1])} for r in top_query]

    # Donations by state - extract state from mailing address
    from collections import defaultdict
    donations_by_state = defaultdict(float)
    all_donations = db.session.query(Donation.mailing_address, Donation.amount).all()
    
    for addr, amt in all_donations:
        state = extract_state_from_address(addr)
        if state:
            donations_by_state[state] += float(amt)

    return jsonify({
        "total_amount": float(total_amount),
        "month_amount": float(month_amount),
        "lives_saved": lives_saved,
        "lives_saved_month": lives_saved_month,
        "cause_a": float(cause_a),
        "cause_b": float(cause_b),
        "top_donors": top_donors,
        "donations_by_state": dict(donations_by_state)
    })

def extract_state_from_address(address):
    """Extract state from mailing address"""
    if not address:
        return None
    
    # Common state abbreviations
    states = {
        'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
        'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
        'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
        'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
        'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
    }
    
    lines = [line.strip() for line in address.splitlines() if line.strip()]
    if not lines:
        return None
    
    # Look for state in the last line (typically "City, State ZIP")
    last_line = lines[-1].upper()
    for state in states:
        if state in last_line:
            return state
    
    return None