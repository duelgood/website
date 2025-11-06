import os
import requests
import logging
from datetime import timezone
logger = logging.getLogger(__name__)

from_email = "noreply@duelgood.org"
causes = {
    "": "Planned Parenthood"
}

def _format_donation_date(donation_dt):
    if donation_date is None:
        return "Unknown date"
    # donation_date may be a datetime in UTC; present it in ISO or human form:
    try:
        # show in UTC with readable format, change to local zone if desired
        return donation_date.astimezone(timezone.utc).strftime("%B %-d, %Y %H:%M %Z")
    except Exception:
        return str(donation_date)

def send_receipt_email(to_email, donor_name, amount_dollars, donation_dt, causes, api_key):
    try:
        causes_str = "\n".join(
                [f"- {c.replace('_amount', '').replace('_', ' ').title()}: ${float(v):.2f}" 
                for c, v in causes.items() if float(v) > 0]
            ) or "(none listed)"
        
        donation_date_str = _format_donation_date(donation_dt)

        response = requests.post(
            "https://api.mailgun.net/v3/duelgood.org/messages",
            auth=("api", api_key),
            data={"from": from_email,
                "to": to_email,
                "subject": "DuelGood Donation Receipt",
                "text": f"""\
Hi {donor_name},

Thank you for your donation! You contributed to the following causes:

{causes_str}

Please retain this email as a receipt for your donation. 

We appreciate your support in making a positive impact.

Warm regards,
DuelGood

Your receipt: 
DuelGood is a 501(c)(3) non-profit corporation. We are registered as DuelGood Incorporated, FEIN 39-4197138. No goods or services were provided to you in return for your donation. The full amount of your  ${amount_dollars:.2f} contribution on {donation_date_str} is deductible for U.S. federal income tax purposes to the extent permitted by law. This email can be used as documentation of this fact.
"""
            })
        
        logger.info(f"Reponse from sending receipt to {to_email}: {response}")

    except Exception as e:
        logger.error(f"Failed to send receipt email to {to_email}: {e}")

