// checkout.js - Payment Intent flow

const stripe = Stripe(
  "pk_test_51S5FMtPaAbpNU2MW6IFPfy7uuVlvMcfDkJmI6xpUEd8AC8VvkwwO87PGhUlfUkPEmio4i3LnDgygBkpl5X68hCSj00SD13F37u"
);

let elements = null;
let paymentElement = null;

document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("donation-form");
  const paymentErrors = document.getElementById("payment-errors");
  const submitButton = form.querySelector('button[type="submit"]');

  // Create payment element when amounts change and total >= $1
  AMOUNT_FIELD_IDS.forEach((id) => {
    const element = document.getElementById(id);
    if (!element) {
      console.error(`Element not found: ${id}`);
      return;
    }
    element.addEventListener("input", async () => {
      const { total } = getDonationAmounts();
      console.log(`Total donation amount: ${total}`);

      if (total >= 1) {
        console.log("Creating payment element...");
        await createPaymentElement(form, paymentErrors);
      }
    });
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
      // Ensure payment element exists
      if (!elements || !paymentElement) {
        const created = await createPaymentElement(form, paymentErrors);
        if (!created) {
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
