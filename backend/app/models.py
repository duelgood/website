from . import db
from datetime import datetime, timezone
from sqlalchemy import Enum

"""
Donation model field summary
- id: Integer primary key (autoincrement).
- time: DateTime (UTC). Timestamp when the donation record refers to (default: now in UTC).
- amount: Numeric(10,2). Decimal money amount (use Python Decimal; precision 10, scale 2).
- display_name: String(100). Public name shown on site; defaults to 'Anonymous'.
- cause: Enum('a','b') - selectable cause/campaign option.
- donation_type: Enum('one-time','monthly','yearly') - donation frequency/type.
- donor_name: String(25). Donor's legal/full name (stored for reporting/compliance).
- email: String(255). Normalized/validated email address.
- street_address: Text. Street portion of mailing address.
- city: Text. City portion of mailing address.
- state: Enum(...state codes...). US state as DB-level enum (only allowed values).
- zip: Integer. ZIP / postal code (stored as integer; note: preserves numeric ZIPs only).
- employer: String(255). Employer name (required for campaign reporting).
- occupation: String(255). Occupation / job title (required for campaign reporting).
- created_at: DateTime. Record creation timestamp (UTC).
- status: Enum('active','cancelled'). Record status for soft-deletes/changes.
"""

class Donation(db.Model):
    __tablename__ = "donations"

    id = db.Column(db.Integer, primary_key=True)
    time = db.Column(db.DateTime, nullable=False, default=datetime.now(timezone.utc))
    amount = db.Column(db.Numeric(10, 2), nullable=False)
    display_name = db.Column(db.String(100), default='Anonymous')
    cause = db.Column(Enum('a', 'b', name='cause_enum', native_enum=True), nullable=False)
    donation_type = db.Column(
        Enum('one-time', 'monthly', 'yearly', name='donation_type_enum', native_enum=True),
        nullable=False,
        default='one-time'
    )
    donor_name = db.Column(db.String(25), nullable=False)
    email = db.Column(db.String(255), nullable=False)
    street_address = db.Column(db.Text, nullable=False)
    city = db.Column(db.Text, nullable=False)
    state = db.Column(
        Enum(
            'AL','AK','AZ','AR','CA','CO','CT','DE','FL','GA','HI','ID','IL','IN','IA',
            'KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ',
            'NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT',
            'VA','WA','WV','WI','WY','DC',
            name='state_enum',
            native_enum=True
        ),
        name='state_enum',
        nullable=False,
        native_enum=True
    )
    zip_code = db.Column(db.String(10))

    created_at = db.Column(db.DateTime, default=datetime.now(timezone.utc))
    status = db.Column(
        Enum('active', 'cancelled', name='donation_status_enum', native_enum=True),
        nullable=False,
        default='active'
    )