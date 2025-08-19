from flask import Blueprint, jsonify
from sqlalchemy import func, extract
from datetime import datetime
from . import db
from .models import Donation

bp = Blueprint("api", __name__, url_prefix="/api")

@bp.route("/stats")
def stats():
    now = datetime.now(datetime.timezone.utc)
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

    # Donations by cause
    cause_a = db.session.query(func.sum(Donation.amount))\
        .filter(Donation.party == "Cause A").scalar() or 0
    cause_b = db.session.query(func.sum(Donation.amount))\
        .filter(Donation.party == "Cause B").scalar() or 0

    # Recent donations (latest 5)
    recent = db.session.query(Donation.donor_name, Donation.amount)\
        .order_by(Donation.time.desc())\
        .limit(5).all()
    recent_donations = [{"donor": r[0], "amount": float(r[1])} for r in recent]

    # Top donors (sum per donor, top 5)
    top_query = db.session.query(
        Donation.donor_name,
        func.sum(Donation.amount).label("total")
    ).group_by(Donation.donor_name)\
     .order_by(func.sum(Donation.amount).desc())\
     .limit(5).all()
    top_donors = [{"donor": r[0], "amount": float(r[1])} for r in top_query]

    # Donations by state (assume 'mailing_address' contains state as last line or parse appropriately)
    from collections import defaultdict
    donations_by_state = defaultdict(float)
    all_donations = db.session.query(Donation.mailing_address, Donation.amount).all()
    for addr, amt in all_donations:
        state = None
        if addr:
            # crude assumption: last non-empty line is state
            lines = [l.strip() for l in addr.splitlines() if l.strip()]
            if lines:
                state = lines[-1]
        if state:
            donations_by_state[state] += float(amt)

    return jsonify({
        "total_amount": float(total_amount),
        "month_amount": float(month_amount),
        "lives_saved": lives_saved,
        "lives_saved_month": lives_saved_month,
        "cause_a": float(cause_a),
        "cause_b": float(cause_b),
        "recent_donations": recent_donations,
        "top_donors": top_donors,
        "donations_by_state": donations_by_state
    })