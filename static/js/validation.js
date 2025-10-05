// validation.js - Donation form validation logic

const AMOUNT_FIELD_IDS = [
  "planned_parenthood_amount",
  "national_right_to_life_committee_amount",
  "everytown_for_gun_safety_amount",
  "nra_foundation_amount",
  "trevor_project_amount",
  "alliance_defending_freedom_amount",
  "duelgood_amount",
];

function getDonationAmounts() {
  const amounts = {};
  let total = 0;

  AMOUNT_FIELD_IDS.forEach((id) => {
    const value = parseFloat(document.getElementById(id).value) || 0;
    amounts[id] = value;
    total += value;
  });

  return { amounts, total };
}

function validateDonationAmounts() {
  const { total } = getDonationAmounts();

  if (total < 1) {
    return {
      valid: false,
      error: "Please enter at least one donation amount of $1 or more.",
    };
  }

  return { valid: true };
}

function validateEmail(email) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

function validateZipCode(zip) {
  return /^\d{5}(-\d{4})?$/.test(zip);
}

function validateForm(form) {
  const errors = [];

  // Validate donation amounts
  const amountValidation = validateDonationAmounts();
  if (!amountValidation.valid) {
    errors.push(amountValidation.error);
  }

  // Validate required fields
  const email = form.email.value.trim();
  if (!email || !validateEmail(email)) {
    errors.push("Please enter a valid email address.");
  }

  const legalName = form.legal_name.value.trim();
  if (!legalName) {
    errors.push("Please enter your legal name.");
  }

  const streetAddress = form.street_address.value.trim();
  if (!streetAddress) {
    errors.push("Please enter your street address.");
  }

  const city = form.city.value.trim();
  if (!city) {
    errors.push("Please enter your city.");
  }

  const state = form.state.value;
  if (!state) {
    errors.push("Please select your state.");
  }

  const zip = form.zip.value.trim();
  if (!zip || !validateZipCode(zip)) {
    errors.push("Please enter a valid ZIP code.");
  }

  return {
    valid: errors.length === 0,
    errors: errors,
  };
}

// Make functions globally available for checkout.js
window.AMOUNT_FIELD_IDS = AMOUNT_FIELD_IDS;
window.getDonationAmounts = getDonationAmounts;
window.validateDonationAmounts = validateDonationAmounts;
window.validateForm = validateForm;
