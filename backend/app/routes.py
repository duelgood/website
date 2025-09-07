from flask import Blueprint, request, jsonify, redirect
from . import db
from .models import Donation
from datetime import datetime, timezone
from email_validator import validate_email, EmailNotValidError
from sqlalchemy import extract, func

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

    # instead of dividing the total amount donated by 3000, we need to 
    # divide just the amount that's gone to GiveWell. 
    lives_saved = int(float(total) / 3000)
    lives_saved_month = int(float(month_amount) / 3000)

    a_total = db.session.query(db.func.sum(Donation.amount))\
        .filter(Donation.cause == 'a')\
        .scalar() or 0
    b_total = db.session.query(db.func.sum(Donation.amount))\
        .filter(Donation.cause == 'b')\
        .scalar() or 0
    
    # Top donors (by display_name)
    top_all_rows = db.session.query(
        Donation.display_name,
        func.sum(Donation.amount).label('total')
    ).group_by(Donation.display_name)\
     .order_by(func.sum(Donation.amount).desc())\
     .limit(10).all()
    top_donors = [{"donor": name or "Anonymous", "amount": float(total or 0)} for name, total in top_all_rows]

    # Top donors this month (by display_name)
    top_month_rows = db.session.query(
        Donation.display_name,
        func.sum(Donation.amount).label('total')
    ).filter(extract('year', Donation.time) == now.year)\
     .filter(extract('month', Donation.time) == now.month)\
     .group_by(Donation.display_name)\
     .order_by(func.sum(Donation.amount).desc())\
     .limit(10).all()
    top_donors_month = [{"donor": name or "Anonymous", "amount": float(total or 0)} for name, total in top_month_rows]

    # we need a way to associate all the donations 
    # that a given donor has ever made with that donor
    # we probably need to update our schema, or just 
    # allow one-time6 donations? but recurring donations 
    # are far more effective. 

    # Donations by state (map code -> full name)
    STATE_NAMES = {
        'AL':'Alabama','AK':'Alaska','AZ':'Arizona','AR':'Arkansas','CA':'California','CO':'Colorado','CT':'Connecticut',
        'DE':'Delaware','FL':'Florida','GA':'Georgia','HI':'Hawaii','ID':'Idaho','IL':'Illinois','IN':'Indiana','IA':'Iowa',
        'KS':'Kansas','KY':'Kentucky','LA':'Louisiana','ME':'Maine','MD':'Maryland','MA':'Massachusetts','MI':'Michigan',
        'MN':'Minnesota','MS':'Mississippi','MO':'Missouri','MT':'Montana','NE':'Nebraska','NV':'Nevada','NH':'New Hampshire',
        'NJ':'New Jersey','NM':'New Mexico','NY':'New York','NC':'North Carolina','ND':'North Dakota','OH':'Ohio',
        'OK':'Oklahoma','OR':'Oregon','PA':'Pennsylvania','RI':'Rhode Island','SC':'South Carolina','SD':'South Dakota',
        'TN':'Tennessee','TX':'Texas','UT':'Utah','VT':'Vermont','VA':'Virginia','WA':'Washington','WV':'West Virginia',
        'WI':'Wisconsin','WY':'Wyoming','DC':'District of Columbia'
    }
    state_rows = db.session.query(Donation.state, func.sum(Donation.amount))\
        .group_by(Donation.state).all()
    donations_by_state = {}
    for code, amt in state_rows:
        if not code:
            continue
        name = STATE_NAMES.get(code, code)
        donations_by_state[name] = float(amt or 0)

    return jsonify({
        "total_amount": float(total),
        "donation_count": int(count),
        "month_amount": float(month_amount),
        "lives_saved": lives_saved,
        "lives_saved_month": lives_saved_month,
        "a": float(a_total),
        "b": float(b_total),
        "cause_a": float(a_total),
        "cause_b": float(b_total),
        "top_donors": top_donors,
        "top_donors_month": top_donors_month,
        "donations_by_state": donations_by_state
    })

# list recent donations
@bp.route("/donations", methods=["GET"])
def get_donations():
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
def post_donations():
    """
    Accept form POSTs from /pages/donate.shtml. Expects form fields:
    Multiple cause-specific amount fields, display_name, email, legal_name, 
    street_address, city, state, zip, optional timestamp.
    """
    try:
        form = request.form
        
        # Define all possible causes and their form field names
        cause_fields = {
            'planned_parenthood_amount': 'Planned Parenthood',
            'national_right_to_life_committee_amount': 'National Right to Life Committee',
            'everytown_for_gun_safety_amount': 'Everytown for Gun Safety',
            'nra_foundation_amount': 'NRA Foundation',
            'trevor_project_amount': 'Trevor Project',
            'alliance_defending_freedom_amount': 'Alliance Defending Freedom',
            'duelgood_amount': 'DuelGood'
        }
        
        # Parse and validate donation amounts
        donations = []
        total_amount = 0
        
        for field_name, cause_name in cause_fields.items():
            try:
                amount = float(form.get(field_name) or 0)
                if amount < 0:
                    return jsonify({'error': f'Donation amounts cannot be negative'}), 400
                if amount > 0:
                    donations.append({'cause': cause_name, 'amount': amount})
                    total_amount += amount
            except ValueError:
                return jsonify({'error': f'Invalid amount for {cause_name}'}), 400
        
        # Validate that at least one donation exists and meets minimum
        if not donations:
            return jsonify({'error': 'Please select at least one cause to donate to'}), 400
        
        if total_amount < 1:
            return jsonify({'error': 'Minimum total donation is $1'}), 400
        
        # Validate contact information
        donor_name = form.get('legal_name', '').strip()
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
        display_name = form.get('display_name', '').strip() or 'Anonymous'
        
        # Validate required fields
        required_fields = [donor_name, email, street_address, city, state, zip_code]
        if not all(required_fields):
            return jsonify({'error': 'Missing required contact information'}), 400
        
        # Validate ZIP code format (basic US ZIP validation)
        import re
        if not re.match(r'^\d{5}(-\d{4})?$', zip_code):
            return jsonify({'error': 'Invalid ZIP code format'}), 400
        
        # Validate state code
        valid_states = {
            'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
            'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
            'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
            'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
            'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC'
        }
        if state not in valid_states:
            return jsonify({'error': 'Invalid state code'}), 400
        
        # Handle timestamp
        timestamp = form.get('timestamp')
        if timestamp:
            try:
                time_val = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
            except Exception:
                time_val = datetime.now(timezone.utc)
        else:
            time_val = datetime.now(timezone.utc)
        
        # Create donation records for each cause
        donation_records = []
        for donation_info in donations:
            donation = Donation(
                time=time_val,
                amount=donation_info['amount'],
                display_name=display_name,
                cause=donation_info['cause'],
                donor_name=donor_name,
                email=email,
                street_address=street_address,
                city=city,
                state=state,
                zip_code=zip_code
            )
            donation_records.append(donation)
            db.session.add(donation)
        
        db.session.commit()
        
        return redirect(f'https://duelgood.org/thank-you', code=302)
        
    except Exception as e:
        db.session.rollback()
        # keep server logs for debugging
        print('Error in /api/donations:', e)
        return jsonify({'error': e}), 500


# we would like to do jinja templating to display a custom 
# thank you message depending on the cause donated to

@bp.route("/health", methods=["GET"])
def get_health():
    return jsonify({"status": "ok"}), 200