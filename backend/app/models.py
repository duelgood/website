from . import db
from datetime import datetime

class Donation(db.Model):
    __tablename__ = "donations"

    id = db.Column(db.Integer, primary_key=True)
    time = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    amount = db.Column(db.Numeric(10, 2), nullable=False)
    display_name = db.Column(db.String(100), default='Anonymous')
    party = db.Column(db.String(50), nullable=False)  # 'democrat' or 'republican'
    donation_type = db.Column(db.String(20), default='one-time')  # 'one-time', 'monthly', 'yearly'
    donor_name = db.Column(db.String(200), nullable=False)  # legal name
    email = db.Column(db.String(255), nullable=False)
    mailing_address = db.Column(db.Text, nullable=False)
    employer = db.Column(db.String(200), nullable=False)
    occupation = db.Column(db.String(200), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    status = db.Column(db.String(20), default='active')

    def __repr__(self):
        return f'<Donation {self.id}: ${self.amount} from {self.donor_name}>'