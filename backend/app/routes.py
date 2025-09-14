from flask import Blueprint, request, jsonify, redirect, current_app
from . import db
from .models import Donation
from datetime import datetime, timezone
from email_validator import validate_email, EmailNotValidError
from sqlalchemy import extract, func
import os
import stripe

def read_secret(name):
    path = f"/run/secrets/{name}"
    try:
        with open(path) as f:
            return f.read().strip()
    except FileNotFoundError:
        return os.environ.get(name)

stripe.api_key = read_secret("stripe_secret_key")
endpoint_secret = read_secret("stripe_webhook_secret")

bp = Blueprint("api", __name__, url_prefix="/api")

@bp.route("/stripe/webhook", methods=["POST"])
def stripe_webhook():
    payload = request.data
    sig_header = request.headers.get("Stripe-Signature")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, endpoint_secret
        )
    except ValueError:
        # Invalid payload
        return "Bad request", 400
    except stripe.error.SignatureVerificationError:
        # Invalid signature
        return "Unauthorized", 400

    # --- Handle event types ---
    if event["type"] == "payment_intent.succeeded":
        intent = event["data"]["object"]
        handle_successful_donation(intent)
    elif event["type"] == "payment_intent.payment_failed":
        intent = event["data"]["object"]
        error_message = intent["last_payment_error"]["message"]
        print(f"Payment failed: {error_message}")

    return "OK", 200

def handle_successful_donation(intent):
    """
    Called when Stripe reports a successful donation payment.
    intent is a dict with payment details and metadata.
    """
    # Extract metadata you stored when creating PaymentIntent
    donor_name = intent["metadata"].get("donor_name")
    donations_str = intent["metadata"].get("donations")
    email = intent.get("receipt_email")

    # You may want to parse donations_str back into Python data
    import ast
    try:
        donations = ast.literal_eval(donations_str)
    except Exception:
        donations = []

    # Record each donation in your DB

    time_val = datetime.now(timezone.utc)

    for d in donations:
        donation = Donation(
            time=time_val,
            amount=d["amount"],
            display_name="Anonymous",   # or pull from metadata if you passed it
            cause=d["cause"],
            donor_name=donor_name,
            email=email,
            street_address="",  # optional if you stored these in metadata
            city="",
            state="",
            zip_code=""
        )
        db.session.add(donation)

    db.session.commit()
    print(f"Recorded successful donation from {donor_name} (${intent['amount']/100:.2f})")

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

    # these causes are completely outdated and need to be updated

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
    try:
        form = request.form

        cause_fields = {
            'planned_parenthood_amount': 'Planned Parenthood',
            'national_right_to_life_committee_amount': 'National Right to Life Committee',
            'everytown_for_gun_safety_amount': 'Everytown for Gun Safety',
            'nra_foundation_amount': 'NRA Foundation',
            'trevor_project_amount': 'Trevor Project',
            'alliance_defending_freedom_amount': 'Alliance Defending Freedom',
            'duelgood_amount': 'DuelGood'
        }

        donations = []
        total_amount = 0
        for field_name, cause_name in cause_fields.items():
            try:
                amount = float(form.get(field_name) or 0)
                if amount > 0:
                    donations.append({'cause': cause_name, 'amount': amount})
                    total_amount += amount
            except ValueError:
                return jsonify({'error': f'Invalid amount for {cause_name}'}), 400

        if total_amount < 1:
            return jsonify({'error': 'Minimum donation is $1'}), 400

        # Convert to cents
        total_cents = int(total_amount * 100)

        email = (form.get('email') or '').strip()
        try:
            v = validate_email(email)
            # normalized (lowercased, etc.)
            email = v.email
        except EmailNotValidError as e:
            return jsonify({'error': f'{email} is an invalid email address'}), 400

        donor_name = (form.get('legal_name') or '').strip()

        street_address = form.get('street_address', '').strip()
        city = form.get('city', '').strip()
        state = (form.get('state') or '').strip().upper()
        zip_code = form.get('zip', '').strip()
        display_name = form.get('display_name', '').strip() or 'Anonymous'

        # we want to get rid of this and allow international addresses too
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
    
        
        required_fields = [donor_name, email, street_address, city, state, zip_code]
        if not all(required_fields):
            return jsonify({'error': 'Missing required contact information'}), 400
        
        metadata = {}
        for cause in [
            "planned_parenthood",
            "national_right_to_life_committee",
            "everytown_for_gun_safety",
            "nra_foundation",
            "trevor_project",
            "alliance_defending_freedom",
            "duelgood"
        ]:
            field_name = f"{cause}_amount"
            amount = form.get(field_name, "0")
            metadata[field_name] = amount

        intent = stripe.PaymentIntent.create(
            amount=total_cents,
            currency="usd",
            automatic_payment_methods={"enabled": True},
            receipt_email=email,
            metadata={
                "donor_name": donor_name,
                "email": email,
                "donations": str(donations),
                "display_name": display_name,
                "street_address": street_address,
                "city": city, 
                "state": state,
                "zip_code": zip_code,
                **metadata
            },
        )

        return jsonify({
            "clientSecret": intent.client_secret
        })

    except Exception as e:
        # log error with logging utility when added
        current_app.logger.error("Unhandled exception in /donations", exc_info=True)
        return jsonify({'error': 'Internal server error'}), 500


@bp.route("/setup-intent", methods=["POST"])
def create_setup_intent():
    """
    Create a SetupIntent so the frontend can render the Payment Element
    immediately on page load.
    """
    try:
        intent = stripe.SetupIntent.create(
            automatic_payment_methods={"enabled": True}
        )
        return jsonify({"clientSecret": intent.client_secret})
    except Exception as e:
        current_app.logger.error("Error creating SetupIntent", exc_info=True)
        return jsonify({"error": "Failed to initialize payment form"}), 500

@bp.route("/health", methods=["GET"])
def get_health():
    return jsonify({"status": "ok"}), 200