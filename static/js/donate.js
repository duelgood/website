document.addEventListener("DOMContentLoaded", async function () {
  const form = document.getElementById("donation-form");
  const paymentErrors = document.getElementById("payment-errors");
  const stripe = Stripe(
    "pk_test_51S5FMtPaAbpNU2MW6IFPfy7uuVlvMcfDkJmI6xpUEd8AC8VvkwwO87PGhUlfUkPEmio4i3LnDgygBkpl5X68hCSj00SD13F37u"
  );

  const amountIds = [
    "planned_parenthood_amount",
    "national_right_to_life_committee_amount",
    "everytown_for_gun_safety_amount",
    "nra_foundation_amount",
    "trevor_project_amount",
    "alliance_defending_freedom_amount",
    "duelgood_amount",
  ];

  let elements, paymentElement;

  // --- helpers ---
  function enforceMinZero() {
    amountIds.forEach((id) => {
      const input = document.getElementById(id);
      input.addEventListener("input", () => {
        if (parseFloat(input.value) < 0) input.value = "0";
      });
      input.addEventListener("blur", () => {
        if (input.value === "") input.value = "0";
      });
    });
  }

  async function mountPaymentElement(clientSecret) {
    elements = stripe.elements({ clientSecret });
    paymentElement = elements.create("payment");
    paymentElement.mount("#payment-element");
  }

  // --- setup ---
  enforceMinZero();

  try {
    const response = await fetch("/api/setup-intent", {
      method: "POST",
    });

    if (!response.ok) {
      throw new Error("Failed to initialize payment form");
    }

    const { clientSecret } = await response.json();
    if (clientSecret) {
      await mountPaymentElement(clientSecret);
    } else {
      paymentErrors.textContent = "Could not initialize payment form";
    }
  } catch (err) {
    console.error("Payment form initialization error:", err);
    paymentErrors.textContent =
      "Payment form failed to load. Please try again.";
  }

  // --- form submit ---
  form.addEventListener("submit", async function (e) {
    e.preventDefault();
    paymentErrors.textContent = "";

    // 1. Validate at least one donation >= $1
    const hasOneAboveOne = amountIds.some(
      (id) => parseFloat(document.getElementById(id).value) >= 1
    );
    if (!hasOneAboveOne) {
      paymentErrors.textContent =
        "Please enter at least one donation amount of $1 or more.";
      return;
    }

    try {
      // 2. Send donation + donor info to backend -> PaymentIntent
      const formData = new FormData(form);
      const res = await fetch("/api/donations", {
        method: "POST",
        body: formData,
      });
      const { clientSecret, error } = await res.json();
      if (error) {
        paymentErrors.textContent = error;
        return;
      }

      // 3. Confirm payment with redirect
      const { error: stripeError } = await stripe.confirmPayment({
        clientSecret,
        confirmParams: {
          return_url: "https://duelgood.org/thank-you",
        },
      });

      if (stripeError) {
        // This shows *only if* an immediate client-side error (e.g. validation)
        paymentErrors.textContent = stripeError.message;
      }

      // If payment succeeds or needs next steps, Stripe will redirect automatically.
    } catch (err) {
      console.error("Donation error:", err);
      paymentErrors.textContent =
        "An unexpected error occurred. Please try again.";
    }
  });
});
