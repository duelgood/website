import os
import requests
import logging
logger = logging.getLogger(__name__)

from_email = "noreply@duelgood.org"

def send_receipt_email(to_email, donor_name, amount_dollars, causes, api_key):
    try:
        causes_str = "\n".join(
                [f"- {c.replace('_amount', '').replace('_', ' ').title()}: ${float(v):.2f}" 
                for c, v in causes.items() if float(v) > 0]
            ) or "(none listed)"

        response = requests.post(
            "https://api.mailgun.net/v3/duelgood.org/messages",
            auth=("api", api_key),
            data={"from": from_email,
                "to": to_email,
                "subject": "DuelGood Donation Receipt",
                "text": f"""\
Hi {donor_name},

Thank you for your generous donation of ${amount_dollars:.2f}!

You contributed to the following causes:
{causes_str}

We appreciate your support in making a positive impact.

Warm regards,
DuelGood
"""
            })
        
        logger.info(f"Reponse from sending receipt to {to_email}: {response}")

    except Exception as e:
        logger.error(f"Failed to send receipt email to {to_email}: {e}")

