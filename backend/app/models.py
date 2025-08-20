from . import db
from datetime import datetime, timezone
from flask_sqlalchemy import Enum

class Donation(db.Model):
    __tablename__ = "donations"

    id = db.Column(db.Integer, primary_key=True)
    time = db.Column(db.DateTime, nullable=False, default=datetime.now(timezone.utc))
    amount = db.Column(db.Numeric(10, 2), nullable=False)
    display_name = db.Column(db.String(100), default='Anonymous')

    # a: Republican, b: Democrat
    cause = db.Column(Enum('a', 'b', name='cause_enum', native_enum=True), nullable=False)
    donation_type = db.Column(
        Enum('one-time', 'monthly', 'yearly', name='donation_type_enum', native_enum=True),
        nullable=False,
        default='one-time'
    )
    # full legal name
    donor_name = db.Column(db.String(25), nullable=False)
    # 
    email = db.Column(db.String(255), nullable=False)
    mailing_address = db.Column(db.Text, nullable=False)
    employer = db.Column(db.String(255), nullable=False)
    occupation = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.now(timezone.utc))
    status = db.Column(
        Enum('active', 'cancelled', name='donation_status_enum', native_enum=True),
        nullable=False,
        default='active'
    )