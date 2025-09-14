document.addEventListener("DOMContentLoaded", async function () {
  const form = document.getElementById("donation-form");
  const paymentErrors = document.getElementById("card-errors");

  const stripe = Stripe("pk_test_51S5FMtPaAbpNU2MW6IFPfy7uuVlvMcfDkJmI6xpUEd8AC8VvkwwO87PGhUlfUkPEmio4i3LnDgygBkpl5X68hCSj00SD13F37u");

  const amountIds = [
    "planned_parenthood_amount",
    "national_right_to_life_committee_amount",
    "everytown_for_gun_safety_amount",
    "nra_foundation_amount",
    "trevor_project_amount",
    "alliance_defending_freedom_amount",
    "duelgood_amount",
  ];

  // Enforce min=0 and reset empty -> 0
  amountIds.forEach((id) => {
    const input = document.getElementById(id);
    input.addEventListener("input", () => {
      if (parseFloat(input.value) < 0) input.value = "0";
    });
    input.addEventListener("blur", () => {
      if (input.value === "") input.value = "0";
    });
  });

  let elements;
  let paymentElement;

  async function mountPaymentElement(clientSecret) {
    if (elements) {
      const old = elements.getElement("payment");
      if (old) old.unmount();
    }
    elements = stripe.elements({ clientSecret });
    paymentElement = elements.create("payment");
    paymentElement.mount("#card-element");
  }

  // ---- 1. On page load: get SetupIntent for initial Payment Element ----
  try {
    const setupRes = await fetch("/api/setup-intent", { method: "POST" });
    const { clientSecret, error } = await setupRes.json();
    if (error) {
      paymentErrors.textContent = error;
    } else {
      await mountPaymentElement(clientSecret);
    }
  } catch (err) {
    console.error("SetupIntent error:", err);
    paymentErrors.textContent = "Failed to initialize payment form.";
  }

  // ---- 2. Handle form submit ----
  form.addEventListener("submit", async function (e) {
    e.preventDefault();
    paymentErrors.textContent = "";

    const hasOneAboveOne = amountIds.some(
      (id) => parseFloat(document.getElementById(id).value) >= 1
    );
    if (!hasOneAboveOne) {
      paymentErrors.textContent =
        "Please enter at least one donation amount of $1 or more.";
      return;
    }

    try {
      // Collect donor + donation info
      const formData = new FormData(form);

      // Create real PaymentIntent with amount + donor info
      const response = await fetch("/api/donations", {
        method: "POST",
        body: formData,
      });

      const { clientSecret, error } = await response.json();
      if (error) {
        paymentErrors.textContent = error;
        return;
      }

      // Re-mount Payment Element with real PaymentIntent
      await mountPaymentElement(clientSecret);

      // Confirm payment
      const { error: stripeError } = await stripe.confirmPayment({
        elements,
        confirmParams: {
          return_url: window.location.origin + "/thank-you",
        },
      });

      if (stripeError) {
        paymentErrors.textContent = stripeError.message;
      }
    } catch (err) {
      console.error("Donation error:", err);
      paymentErrors.textContent =
        "An unexpected error occurred. Please try again.";
    }
  });
});
