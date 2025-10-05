// checkout.js - Payment Intent flow

const stripe = Stripe(
  "pk_test_51S5FMtPaAbpNU2MW6IFPfy7uuVlvMcfDkJmI6xpUEd8AC8VvkwwO87PGhUlfUkPEmio4i3LnDgygBkpl5X68hCSj00SD13F37u"
);

let elements = null;
let paymentElement = null;
let isCreatingPayment = false;

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("donation-form");
  const paymentErrors = document.getElementById("payment-errors");
  const submitButton = form.querySelector('button[type="submit"]');

  // Check if form is complete enough to create payment element
  function isFormReadyForPayment() {
    const { total } = getDonationAmounts();

    // Need at least $1 donation
    if (total < 1) return false;

    // Check required fields are filled
    const email = form.email.value.trim();
    const legalName = form.legal_name.value.trim();
    const street = form.street_address.value.trim();
    const city = form.city.value.trim();
    const state = form.state.value;
    const zip = form.zip.value.trim();

    return email && legalName && street && city && state && zip;
  }

  // Try to create payment element when form becomes ready
  async function tryCreatePaymentElement() {
    if (isCreatingPayment || paymentElement) return;

    if (isFormReadyForPayment()) {
      isCreatingPayment = true;
      console.log("Form is ready, creating payment element...");
      await createPaymentElement(form, paymentErrors);
      isCreatingPayment = false;
    }
  }

  // Watch all form fields for changes
  form.querySelectorAll("input, select").forEach((field) => {
    field.addEventListener("input", tryCreatePaymentElement);
    field.addEventListener("change", tryCreatePaymentElement);
  });

  // Handle form submission
  form.addEventListener("submit", async (e) => {
    e.preventDefault();

    // Validate form (errors will be shown inline)
    const validation = validateForm(form);
    if (!validation.valid) {
      // Scroll to first error
      const firstError = document.querySelector(".field-error, .error");
      if (firstError) {
        firstError.scrollIntoView({ behavior: "smooth", block: "center" });
      }
      return;
    }

    // Disable submit button to prevent double submission
    submitButton.disabled = true;
    submitButton.textContent = "Processing...";

    try {
      // Create payment element if it doesn't exist yet
      if (!elements || !paymentElement) {
        const created = await createPaymentElement(form, paymentErrors);
        if (!created) {
          paymentErrors.textContent =
            "Unable to initialize payment. Please check all fields and try again.";
          paymentErrors.scrollIntoView({ behavior: "smooth", block: "center" });
          submitButton.disabled = false;
          submitButton.textContent = "Submit Donation (Test Mode)";
          return;
        }
      }

      // Confirm the payment
      const { error } = await stripe.confirmPayment({
        elements,
        confirmParams: {
          return_url: window.location.origin + "/thank-you.shtml",
        },
      });

      if (error) {
        // Show payment-specific errors in the payment section
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

async function createPaymentElement(form, errorElement) {
  try {
    console.log("Sending form data to /api/donations...");
    // Create FormData and send to backend
    const formData = new FormData(form);
    const response = await fetch("/api/donations", {
      method: "POST",
      body: formData,
    });

    const data = await response.json();
    console.log("Response from /api/donations:", data);

    if (!response.ok || data.error) {
      // Don't show backend validation errors in payment box
      // They should be handled by inline validation
      console.error("Backend error:", data.error);
      return false;
    }

    // Unmount existing element if present
    if (paymentElement) {
      console.log("Unmounting existing payment element");
      paymentElement.unmount();
    }

    // Create new Elements instance with client secret
    console.log("Creating Stripe elements with clientSecret");
    elements = stripe.elements({ clientSecret: data.clientSecret });
    paymentElement = elements.create("payment");
    paymentElement.mount("#payment-element");
    console.log("Payment element mounted successfully");

    return true;
  } catch (error) {
    console.error("Error in createPaymentElement:", error);
    return false;
  }
}
