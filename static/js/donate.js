const form = document.getElementById("donation-form");

function showError(id, msg) {
  const el = document.getElementById(id);
  if (el) {
    el.textContent = msg || "";
    el.style.display = msg ? "block" : "none";
  }
}

// email is validated on the backend as well
function validateEmail() {
  const email = document.getElementById("email");
  if (!email.value.match(/^[^@\s]+@[^@\s]+\.[^@\s]+$/)) {
    showError("email-error", "Please enter a valid email address.");
    return false;
  }
  showError("email-error", "");
  return true;
}

// amount donated must also be validated on the backend
// this will eventually need to be replaced with a
// payment processor like Stripe or Plaid
function validateAmount() {
  const amount = document.getElementById("amount");
  const val = parseFloat(amount.value);
  if (isNaN(val) || val < 1) {
    showError("amount-error", "Minimum donation is $1.");
    return false;
  }
  showError("amount-error", "");
  return true;
}

// validated on the backend as well
function validateZip() {
  const zip = document.getElementById("zip");
  // fixed regex: single backslashes
  if (!/^\d{5}(-\d{4})?$/.test(zip.value)) {
    showError("zip-error", "Enter a valid ZIP code.");
    return false;
  }
  showError("zip-error", "");
  return true;
}

// validated on the backend
function validateState() {
  const state = document.getElementById("state");
  if (!state.value) {
    showError("state-error", "Please select a state.");
    return false;
  }
  showError("state-error", "");
  return true;
}

// enable/disable submit based on all validators
function allValid() {
  return (
    validateEmail() &&
    validateAmount() &&
    validateZip() &&
    validateState() &&
    document.querySelector('input[name="cause"]:checked') &&
    document.querySelector('input[name="type"]:checked') &&
    document.getElementsByName("legal_name")[0].value.trim() !== "" &&
    document.getElementsByName("street")[0].value.trim() !== "" &&
    document.getElementsByName("city")[0].value.trim() !== "" &&
    document.getElementsByName("employer")[0].value.trim() !== "" &&
    document.getElementsByName("occupation")[0].value.trim() !== ""
  );
}

function updateSubmitState() {
  const btn = document.getElementById("submit-btn");
  if (allValid()) {
    btn.disabled = false;
    btn.classList.remove("disabled");
  } else {
    btn.disabled = true;
    btn.classList.add("disabled");
  }
}

form.addEventListener("submit", async function (e) {
  e.preventDefault();

  const valid =
    validateEmail() && validateAmount() && validateZip() && validateState();
  if (!valid) {
    updateSubmitState();
    return;
  }

  const submitBtn = document.getElementById("submit-btn");
  const originalText = submitBtn.textContent;
  submitBtn.textContent = "Processing...";
  submitBtn.disabled = true;

  try {
    const data = new FormData(form);
    data.append("timestamp", new Date().toISOString());
    if (!data.get("display_name")) data.set("display_name", "Anonymous");

    const street = (data.get("street") || "").trim();
    const city = (data.get("city") || "").trim();
    const state = (data.get("state") || "").trim();
    const zip = (data.get("zip") || "").trim();
    data.set("street_address", street + "\n" + city + ", " + state + " " + zip);

    const resp = await fetch("/api/donations", { method: "POST", body: data });
    if (resp.ok) {
      form.style.display = "none";
      document.getElementById("success-message").style.display = "block";
    } else {
      const json = await resp.json().catch(() => null);
      alert("Error: " + (json?.error || (await resp.text())));
      const text = await resp.text();
      let json = null;
      try {
        json = JSON.parse(text);
      } catch (_) {
        /* not JSON */
      }
      alert("Error: " + (json?.error || text || resp.statusText));
    }
  } catch (err) {
    alert(err);
  } finally {
    submitBtn.textContent = originalText;
    submitBtn.disabled = false;
    updateSubmitState();
  }
});

// wire inputs to live validation and submit button state
document.getElementById("email").addEventListener("input", () => {
  validateEmail();
  updateSubmitState();
});
document.getElementById("amount").addEventListener("input", () => {
  validateAmount();
  updateSubmitState();
});
document.getElementById("zip").addEventListener("input", () => {
  validateZip();
  updateSubmitState();
});
document.getElementById("state").addEventListener("change", () => {
  validateState();
  updateSubmitState();
});
Array.from(
  document.querySelectorAll(
    'input[name="cause"], input[name="type"], input[name="legal_name"], input[name="street"], input[name="city"], input[name="employer"], input[name="occupation"]'
  )
).forEach((el) => el.addEventListener("input", updateSubmitState));

// run once on load
updateSubmitState();
