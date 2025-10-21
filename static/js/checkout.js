const stripe = Stripe(
  "pk_test_51S5FMtPaAbpNU2MW6IFPfy7uuVlvMcfDkJmI6xpUEd8AC8VvkwwO87PGhUlfUkPEmio4i3LnDgygBkpl5X68hCSj00SD13F37u"
);

let currentPaymentIntentId = null;
let elements = null;
let paymentElement = null;
let paymentElementTimer = null;
let isCreatingPayment = false;

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("donation-form");
  const paymentErrors = document.getElementById("payment-errors");
  const submitButton = form.querySelector('button[type="submit"]');

  function isFormReadyForPayment() {
    const { total } = getDonationAmounts();
    if (total < 1) return false;

    const email = form.email.value.trim();
    const legalName = form.legal_name.value.trim();
    const street = form.street_address.value.trim();
    const city = form.city.value.trim();
    const state = form.state.value;
    const zip = form.zip.value.trim();

    return email && legalName && street && city && state && zip;
  }

  async function createOrUpdatePaymentIntent(form, errorElement) {
    try {
      const formData = new FormData(form);
      if (currentPaymentIntentId) {
        formData.append("payment_intent_id", currentPaymentIntentId);
      }

      const response = await fetch("/api/donations", {
        method: "POST",
        body: formData,
      });
      const data = await response.json();

      if (!response.ok || data.error) {
        console.error("Backend error:", data.error);
        return false;
      }

      // If backend returns a new PaymentIntent ID or clientSecret, update UI
      const newId = data.paymentIntentId;
      const newSecret = data.clientSecret;

      const isNewIntent = newId !== currentPaymentIntentId;
      currentPaymentIntentId = newId;

      if (isNewIntent || !paymentElement) {
        if (paymentElement) paymentElement.unmount();
        elements = stripe.elements({ clientSecret: newSecret });
        paymentElement = elements.create("payment");
        paymentElement.mount("#payment-element");
        console.log("Mounted payment element (new or updated intent)");
      }

      return true;
    } catch (error) {
      console.error("Error in createOrUpdatePaymentIntent:", error);
      return false;
    }
  }

  // Debounced recheck
  function tryCreatePaymentElement() {
    clearTimeout(paymentElementTimer);
    paymentElementTimer = setTimeout(async () => {
      if (!isFormReadyForPayment()) return;
      if (isCreatingPayment) return;

      isCreatingPayment = true;
      await createOrUpdatePaymentIntent(form, paymentErrors);
      isCreatingPayment = false;
    }, 800);
  }

  // Watch fields for changes
  form.querySelectorAll("input, select").forEach((field) => {
    field.addEventListener("input", tryCreatePaymentElement);
    field.addEventListener("change", tryCreatePaymentElement);
  });

  // Handle submit
  form.addEventListener("submit", async (e) => {
    e.preventDefault();

    const validation = validateForm(form);
    if (!validation.valid) {
      const firstError = document.querySelector(".field-error, .error");
      if (firstError)
        firstError.scrollIntoView({ behavior: "smooth", block: "center" });
      return;
    }

    submitButton.disabled = true;
    submitButton.textContent = "Processing...";

    try {
      if (!elements || !paymentElement) {
        const created = await createOrUpdatePaymentIntent(form, paymentErrors);
        if (!created) {
          paymentErrors.textContent =
            "Unable to initialize payment. Please check all fields and try again.";
          submitButton.disabled = false;
          submitButton.textContent = "Submit Donation (Test Mode)";
          return;
        }
      }

      const { error } = await stripe.confirmPayment({
        elements,
        confirmParams: {
          return_url: window.location.origin + "/thank-you.shtml",
        },
      });

      if (error) {
        paymentErrors.textContent = error.message;
        paymentErrors.scrollIntoView({ behavior: "smooth", block: "center" });
        submitButton.disabled = false;
        submitButton.textContent = "Submit Donation (Test Mode)";
      }
    } catch (err) {
      console.error("Unexpected error:", err);
      paymentErrors.textContent =
        "An unexpected error occurred. Please try again.";
      submitButton.disabled = false;
      submitButton.textContent = "Submit Donation (Test Mode)";
    }
  });
});
