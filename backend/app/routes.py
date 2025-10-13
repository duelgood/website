from flask import Blueprint, jsonify, request, current_app, render_template_string
import os
import stripe
import logging

logger = logging.getLogger(__name__)

def read_secret(name):
    path = f"/run/secrets/{name}"
    try:
        with open(path) as f:
            return f.read().strip()
    except FileNotFoundError:
        return os.environ.get(name)

stripe.api_key = read_secret("stripe_secret_key")
endpoint_secret = read_secret("stripe_webhook_secret")

TOTAL_DONATIONS_KEY = "total_donations"

bp = Blueprint("api", __name__)

def get_total_from_stripe():
    """Fetch total donations from Stripe (SSOT)"""
    try:
        # Fetch all successful payment intents
        total = 0
        starting_after = None
        
        while True:
            params = {
                "limit": 100,
            }
            if starting_after:
                params["starting_after"] = starting_after
            
            payment_intents = stripe.PaymentIntent.list(**params)
            
            for pi in payment_intents.data:
                if pi.status == "succeeded":
                    total += pi.amount
            
            if not payment_intents.has_more:
                break
            
            starting_after = payment_intents.data[-1].id
        
        # Convert from cents to dollars
        return total / 100
    except Exception as e:
        logger.error(f"Error fetching from Stripe: {e}")
        raise

def get_cached_total():
    """Get total from Redis cache, fallback to Stripe"""
    try:
        cached = current_app.redis_client.get(TOTAL_DONATIONS_KEY)
        if cached is not None:
            return float(cached)
    except Exception as e:
        logger.warning(f"Redis error, fetching from Stripe: {e}")
    
    # Cache miss or error - fetch from Stripe
    total = get_total_from_stripe()
    try:
        current_app.redis_client.set(TOTAL_DONATIONS_KEY, total)
    except Exception as e:
        logger.warning(f"Failed to cache total: {e}")
    
    return total

def update_cached_total(amount_cents):
    """Increment the cached total by the given amount"""
    try:
        current_app.redis_client.incrbyfloat(TOTAL_DONATIONS_KEY, amount_cents / 100)
    except Exception as e:
        logger.error(f"Failed to update cache: {e}")
        # If Redis fails, we'll fetch from Stripe on next request

@bp.route("/api/total", methods=["GET"])
def get_total():
    """API endpoint to get total donations"""
    try:
        total = get_cached_total()
        return jsonify({"total": total}), 200
    except Exception as e:
        logger.error(f"Error getting total: {e}")
        return jsonify({"error": "Failed to fetch total"}), 500

@bp.route("/api/webhook", methods=["POST"])
def stripe_webhook():
    """Handle Stripe webhook events"""
    payload = request.get_data()
    sig_header = request.headers.get("Stripe-Signature")
    
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, endpoint_secret
        )
    except ValueError as e:
        logger.error(f"Invalid payload: {e}")
        return jsonify({"error": "Invalid payload"}), 400
    except stripe.SignatureVerificationError as e:
        logger.error(f"Invalid signature: {e}")
        return jsonify({"error": "Invalid signature"}), 400
    
    # Handle payment intent succeeded event
    if event["type"] == "payment_intent.succeeded":
        payment_intent = event["data"]["object"]
        amount = payment_intent["amount"]
        
        logger.info(f"Payment succeeded: {payment_intent['id']}, amount: {amount}")
        update_cached_total(amount)
    
    return jsonify({"status": "success"}), 200

@bp.route("/api/donations", methods=["POST"])
def create_donation():
    try:
        # Extract and validate form data
        data = request.form
        total = 0
        causes = {}
        
        # Calculate total from cause amounts (convert to cents)
        cause_fields = [
            'planned_parenthood_amount', 'focus_on_the_family_amount',
            'everytown_for_gun_safety_amount', 'nra_foundation_amount',
            'trevor_project_amount', 'family_research_council_amount',
            'duelgood_amount'
        ]
        for field in cause_fields:
            amount_str = data.get(field, '0').strip()
            try: 
                amount = float(amount_str) if amount_str else 0.0
            except ValueError:
                amount = 0.0

            if amount > 0:
                total += amount
                causes[field] = amount
        
        if total < 1:
            return jsonify({"error": "Minimum donation is $1"}), 400
        
        # Validate required fields
        required = ['email', 'legal_name', 'street_address', 'city', 'state', 'zip']
        for field in required:
            if not data.get(field):
                return jsonify({"error": f"Missing {field}"}), 400
        
        # Create Stripe PaymentIntent (amount in cents)
        intent = stripe.PaymentIntent.create(
            amount=int(total * 100),
            currency="usd",
            metadata={
                "display_name": data.get("display_name", "Anonymous"),
                "email": data["email"],
                "legal_name": data["legal_name"],
                **{field: str(amount) for field, amount in causes.items()}
            }
        )
        
        return jsonify({"clientSecret": intent.client_secret}), 200
    
    except Exception as e:
        logger.error(f"Error creating donation: {e}")
        return jsonify({"error": "Failed to create payment intent"}), 500

@bp.route("/api/health", methods=["GET"])
def get_health():
    """Health check endpoint"""
    try:
        # Check Redis connection
        current_app.redis_client.ping()
        redis_status = "ok"
    except Exception as e:
        logger.warning(f"Redis health check failed: {e}")
        redis_status = "error"
    
    return jsonify({
        "status": "ok",
        "redis": redis_status
    }), 200