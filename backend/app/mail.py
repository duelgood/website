import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import logging
logger = logging.getLogger(__name__)

# rewrite this to use SendGrid free tier instead

def send_receipt_email(to_email, donor_name, amount_dollars, causes):
    """Send a thank-you email to the donor."""
    try:
        # OPTION 1: Send via local Postfix (for noreply@duelgood.org)
        smtp_host = "localhost"
        smtp_port = 25 
        from_email = "noreply@duelgood.org"

        # OPTION 2: Send via Gmail SMTP directly (if you need better deliverability)
        # smtp_host = "smtp.gmail.com"
        # smtp_port = 587
        # from_email = "your-personal@gmail.com"  # Gmail will show as "noreply@duelgood.org" via "Send as"
        
        subject = "Thank you for your donation to DuelGood!"

        # Build plain text body
        causes_str = "\n".join(
            [f"- {c.replace('_amount', '').replace('_', ' ').title()}: ${float(v):.2f}" 
             for c, v in causes.items() if float(v) > 0]
        ) or "(none listed)"

        body = f"""\
Hi {donor_name},

Thank you for your generous donation of ${amount_dollars:.2f} to DuelGood!

Your contributions support the following causes:
{causes_str}

We appreciate your support in making a positive impact.

Warm regards,
DuelGood
https://duelgood.org
"""

        msg = MIMEMultipart()
        msg["From"] = from_email
        msg["To"] = to_email
        msg["Subject"] = subject
        msg.attach(MIMEText(body, "plain"))

        with smtplib.SMTP(smtp_host, smtp_port) as server:
            # If using Gmail SMTP directly, add these lines:
            # server.starttls()
            # server.login('your-email@gmail.com', 'your-app-password')
            server.send_message(msg)

        logger.info(f"Receipt email sent to {to_email}")
    except Exception as e:
        logger.error(f"Failed to send receipt email to {to_email}: {e}")