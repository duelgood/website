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
    paymentErrors.textContent = "";

    // Validate form
    const validation = validateForm(form);
    if (!validation.valid) {
      paymentErrors.textContent = validation.errors.join(" ");
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
        paymentErrors.textContent = error.message;
        submitButton.disabled = false;
        submitButton.textContent = "Submit Donation (Test Mode)";
      }
    } catch (err) {
      paymentErrors.textContent =
        "An unexpected error occurred. Please try again.";
      submitButton.disabled = false;
      submitButton.textContent = "Submit Donation (Test Mode)";
    }
  });
});

async function createPaymentElement(form, errorElement) {
  try {
    // Create FormData and send to backend
    const formData = new FormData(form);
    const response = await fetch("/api/donations", {
      method: "POST",
      body: formData,
    });

    const data = await response.json();

    if (!response.ok || data.error) {
      errorElement.textContent = data.error || "Failed to initialize payment";
      return false;
    }

    // Unmount existing element if present
    if (paymentElement) {
      paymentElement.unmount();
    }

    // Create new Elements instance with client secret
    elements = stripe.elements({ clientSecret: data.clientSecret });
    paymentElement = elements.create("payment");
    paymentElement.mount("#payment-element");

    return true;
  } catch (error) {
    errorElement.textContent =
      "Failed to initialize payment. Please try again.";
    return false;
  }
}
