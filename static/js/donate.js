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

  let elements;
  let paymentElement;

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

  async function initPaymentBox() {
    try {
      const res = await fetch("/api/setup-intent", { method: "POST" });
      const { clientSecret, error } = await res.json();
      if (error) {
        paymentErrors.textContent = error;
        return;
      }
      elements = stripe.elements({ clientSecret });
      paymentElement = elements.create("payment");
      paymentElement.mount("#payment-element");
    } catch (err) {
      console.error("Error initializing payment box:", err);
      paymentErrors.textContent = "Could not load payment form.";
    }
  }

  // --- setup ---
  enforceMinZero();
  await initPaymentBox();

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

      // 3. Re-mount Payment Element with PaymentIntent
      elements = stripe.elements({ clientSecret });
      paymentElement = elements.create("payment");
      paymentElement.mount("#card-element");

      // 4. Confirm payment
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
