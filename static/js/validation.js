// form validation logic

const AMOUNT_FIELD_IDS = [
  "planned_parenthood_amount",
  "focus_on_the_family_amount",
  "everytown_for_gun_safety_amount",
  "nra_foundation_amount",
  "trevor_project_amount",
  "family_research_council_amount",
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

function showFieldError(fieldName, message) {
  const field = document.querySelector(`[name="${fieldName}"]`);
  if (!field) return;

  // Remove any existing error
  clearFieldError(fieldName);

  // Add error class to field
  field.classList.add("error");

  // Create and insert error message
  const errorDiv = document.createElement("div");
  errorDiv.className = "field-error";
  errorDiv.textContent = message;
  errorDiv.setAttribute("data-field", fieldName);

  // Insert after the field (or after its parent label if wrapped)
  const parent = field.closest("label") || field.parentElement;
  parent.insertAdjacentElement("afterend", errorDiv);
}

function clearFieldError(fieldName) {
  const field = document.querySelector(`[name="${fieldName}"]`);
  if (field) {
    field.classList.remove("error");
  }

  const errorDiv = document.querySelector(
    `.field-error[data-field="${fieldName}"]`
  );
  if (errorDiv) {
    errorDiv.remove();
  }
}

function clearAllErrors() {
  document
    .querySelectorAll(".error")
    .forEach((el) => el.classList.remove("error"));
  document.querySelectorAll(".field-error").forEach((el) => el.remove());

  const paymentErrors = document.getElementById("payment-errors");
  if (paymentErrors) {
    paymentErrors.textContent = "";
  }
}

function validateForm(form) {
  clearAllErrors();
  let isValid = true;

  // Validate donation amounts
  const amountValidation = validateDonationAmounts();
  if (!amountValidation.valid) {
    // Show error in the causes fieldset
    const causesFieldset = document.querySelector("fieldset legend");
    if (causesFieldset) {
      const errorDiv = document.createElement("div");
      errorDiv.className = "field-error fieldset-error";
      errorDiv.textContent = amountValidation.error;
      causesFieldset.parentElement.insertBefore(
        errorDiv,
        causesFieldset.nextSibling
      );
    }
    isValid = false;
  }

  // Validate email
  const email = form.email.value.trim();
  if (!email) {
    showFieldError("email", "Email address is required.");
    isValid = false;
  } else if (!validateEmail(email)) {
    showFieldError("email", "Please enter a valid email address.");
    isValid = false;
  }

  // Validate legal name
  const legalName = form.legal_name.value.trim();
  if (!legalName) {
    showFieldError("legal_name", "Legal name is required.");
    isValid = false;
  }

  // Validate street address
  const streetAddress = form.street_address.value.trim();
  if (!streetAddress) {
    showFieldError("street_address", "Street address is required.");
    isValid = false;
  }

  // Validate city
  const city = form.city.value.trim();
  if (!city) {
    showFieldError("city", "City is required.");
    isValid = false;
  }

  // Validate state
  const state = form.state.value;
  if (!state) {
    showFieldError("state", "Please select your state.");
    isValid = false;
  }

  // Validate ZIP
  const zip = form.zip.value.trim();
  if (!zip) {
    showFieldError("zip", "ZIP code is required.");
    isValid = false;
  } else if (!validateZipCode(zip)) {
    showFieldError(
      "zip",
      "Please enter a valid ZIP code (e.g., 12345 or 12345-1234)."
    );
    isValid = false;
  }

  return { valid: isValid };
}

// Setup real-time validation on blur
function setupFieldValidation() {
  const form = document.getElementById("donation-form");
  if (!form) return;

  // Email validation
  const emailField = form.email;
  if (emailField) {
    emailField.addEventListener("blur", () => {
      const value = emailField.value.trim();
      if (value && !validateEmail(value)) {
        showFieldError("email", "Please enter a valid email address.");
      } else {
        clearFieldError("email");
      }
    });
  }

  // ZIP validation
  const zipField = form.zip;
  if (zipField) {
    zipField.addEventListener("blur", () => {
      const value = zipField.value.trim();
      if (value && !validateZipCode(value)) {
        showFieldError(
          "zip",
          "Please enter a valid ZIP code (e.g., 12345 or 12345-1234)."
        );
      } else {
        clearFieldError("zip");
      }
    });
  }

  // Clear error on input
  form.querySelectorAll("input, select").forEach((field) => {
    field.addEventListener("input", () => {
      if (field.name) {
        clearFieldError(field.name);
      }
    });
  });
}

// Initialize when DOM is ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", setupFieldValidation);
} else {
  setupFieldValidation();
}

// Make functions globally available for checkout.js
window.AMOUNT_FIELD_IDS = AMOUNT_FIELD_IDS;
window.getDonationAmounts = getDonationAmounts;
window.validateDonationAmounts = validateDonationAmounts;
window.validateForm = validateForm;
window.clearAllErrors = clearAllErrors;
