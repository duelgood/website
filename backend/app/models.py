from . import db

class Donation(db.Model):
    __tablename__ = "donations"

    id = db.Column(db.Integer, primary_key=True)
    time = db.Column(db.DateTime, nullable=False)
    amount = db.Column(db.Numeric(10, 2), nullable=False)
    display_name = db.Column(db.String(100))
    party = db.Column(db.String(50))
    donor_name = db.Column(db.String(200), nullable=False)
    mailing_address = db.Column(db.Text)
    employer = db.Column(db.String(200))
    occupation = db.Column(db.String(200))