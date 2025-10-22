from flask import Blueprint, jsonify, request, current_app, render_template_string
import os
import stripe
import logging
import json

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

CAUSES_KEY = "causes"  # Hash: cause -> total amount
STATES_KEY = "states"  # Hash: state -> total amount
DONORS_KEY = "donors"  # List: JSON strings of {"name": ..., "amount": ..., "email": ...}

bp = Blueprint("api", __name__)

def get_cached_stats():
    """Get all stats from Redis, fallback to rebuilding from Stripe"""
    try:
        causes = current_app.redis_client.hgetall(CAUSES_KEY) or {}
        states = current_app.redis_client.hgetall(STATES_KEY) or {}
        donors_raw = current_app.redis_client.lrange(DONORS_KEY, 0, -1) or []
        donors = [json.loads(d) for d in donors_raw]  # List of dicts
        return {
            "causes": {k: float(v) for k, v in causes.items()},
            "states": {k: float(v["parsedValue"]) if isinstance(v, dict) else float(v) for k, v in states.items()},
            "donors": donors
        }
    except Exception as e:
        logger.warning(f"Redis error for stats: {e}")
    
    # Rebuild from Stripe
    return rebuild_stats_from_stripe()

def rebuild_stats_from_stripe():
    """Rebuild all stats from Stripe PaymentIntents"""
    try:
        total = 0
        causes = {}
        states = {}
        donors = []
        starting_after = None
        
        while True:
            payment_intents = stripe.PaymentIntent.search(
                query="status:'succeeded'",
                limit=100,
            )
            for pi in payment_intents.data:
                amount_dollars = pi.amount / 100
                total += amount_dollars
                metadata = pi.metadata
                
                # Aggregate causes
                for cause in ['planned_parenthood_amount', 'focus_on_the_family_amount', 
                                'everytown_for_gun_safety_amount', 'nra_foundation_amount',
                                'trevor_project_amount', 'family_research_council_amount',
                                'duelgood_amount']:
                    if cause in metadata:
                        causes[cause] = causes.get(cause, 0) + float(metadata[cause])
                
                # Aggregate states
                if 'state' in metadata:
                    states[metadata['state']] = states.get(metadata['state'], 0) + amount_dollars
                
                # Collect donors (last 100 for simplicity)
                if len(donors) < 100:
                    donors.append({
                        "name": metadata.get('display_name', 'Anonymous'),
                        "amount": amount_dollars,
                    })
            
            if not payment_intents.has_more:
                break
            starting_after = payment_intents.data[-1].id
        
        # Cache in Redis
        current_app.redis_client.hset(CAUSES_KEY, mapping={k: str(v) for k, v in causes.items()})
        current_app.redis_client.hset(STATES_KEY, mapping={k: str(v) for k, v in states.items()})
        current_app.redis_client.delete(DONORS_KEY)  # Clear list
        for d in reversed(donors):
            current_app.redis_client.lpush(DONORS_KEY, json.dumps(d))
        current_app.redis_client.ltrim(DONORS_KEY, 0, 99)
        
        return {
            "total": total,
            "causes": causes,
            "states": states,
            "donors": donors
        }
    except Exception as e:
        logger.error(f"Error rebuilding stats: {e}")
        raise

def update_cached_stats(metadata, amount_dollars):
    """Update caches with new payment metadata"""
    try:        
        # Update causes
        for cause in ['planned_parenthood_amount', 'focus_on_the_family_amount', 
                      'everytown_for_gun_safety_amount', 'nra_foundation_amount',
                      'trevor_project_amount', 'family_research_council_amount',
                      'duelgood_amount']:
            if cause in metadata:
                current_app.redis_client.hincrbyfloat(CAUSES_KEY, cause, float(metadata[cause]))
        
        # Update states
        if 'state' in metadata:
            current_app.redis_client.hincrbyfloat(STATES_KEY, metadata['state'], amount_dollars)
        
        # Add donor
        donor = {
            "name": metadata.get('display_name', 'Anonymous'),
            "amount": amount_dollars,
            "email": metadata.get('email', '')
        }
        current_app.redis_client.lpush(DONORS_KEY, json.dumps(donor))
        # Trim list to last 100
        current_app.redis_client.ltrim(DONORS_KEY, 0, 99)
    except Exception as e:
        logger.error(f"Failed to update caches: {e}")
    
@bp.route("/api/stats", methods=["GET"])
def get_stats():
    try:
        stats = get_cached_stats()

        causes = stats["causes"]
        pp = causes.get("planned_parenthood_amount", 0)
        fotf = causes.get("focus_on_the_family_amount", 0)
        eg = causes.get("everytown_for_gun_safety_amount", 0)
        nra = causes.get("nra_foundation_amount", 0)
        tp = causes.get("trevor_project_amount", 0)
        frc = causes.get("family_research_council_amount", 0)
        givewell = 2 * (min(pp, fotf) + min(eg, nra) + min(tp, frc))
        stats["givewell"] = givewell
        
        return jsonify(stats), 200
    except Exception as e:
        logger.error(f"Error getting stats: {e}")
        return jsonify({"error": "Failed to fetch stats"}), 500

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
    
    if event["type"] == "payment_intent.succeeded":
        payment_intent = event["data"]["object"]
        amount_dollars = payment_intent["amount"] / 100
        metadata = payment_intent["metadata"]
        
        logger.info(f"Payment succeeded: {payment_intent['id']}, amount: {amount_dollars}")
        update_cached_stats(metadata, amount_dollars)
    
    return jsonify({"status": "success"}), 200

@bp.route("/api/donations", methods=["POST"])
def create_or_update_donation():
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
        metadata = {
            "display_name": data.get("display_name", "Anonymous"),
            "email": data["email"],
            "legal_name": data["legal_name"],
            "street_address": data["street_address"],
            "city": data["city"],
            "state": data["state"],
            "zip": data["zip"],
            **{field: str(amount) for field, amount in causes.items()},
        }

        payment_intent_id = data.get("payment_intent_id")
        if payment_intent_id:
            try:
                intent = stripe.PaymentIntent.modify(
                    payment_intent_id,
                    amount=int(total * 100),
                    currency="usd",
                    metadata=metadata,
                )
            except:
                # Intent not found or already confirmed, fall back to creating a new one
                intent = stripe.PaymentIntent.create(
                    amount=int(total * 100),
                    currency="usd",
                    metadata=metadata,
                )
        else:
            # Create a new PaymentIntent
            intent = stripe.PaymentIntent.create(
                amount=int(total * 100),
                currency="usd",
                metadata=metadata,
            )
        
        return jsonify({
            "clientSecret": intent.client_secret,
            "paymentIntentId": intent.id
        }), 200
    
    except Exception as e:
        logger.error(f"Error creating/udating donation: {e}")
        return jsonify({"error": "Failed to create or update payment intent"}), 500

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