document.addEventListener("DOMContentLoaded", async () => {
  const stripe = Stripe(
    "pk_test_51S5FMtPaAbpNU2MW6IFPfy7uuVlvMcfDkJmI6xpUEd8AC8VvkwwO87PGhUlfUkPEmio4i3LnDgygBkpl5X68hCSj00SD13F37u"
  );

  const form = document.getElementById("donation-form");
  const paymentErrors = document.getElementById("payment-errors");

  const amountIds = [
    "planned_parenthood_amount",
    "national_right_to_life_committee_amount",
    "everytown_for_gun_safety_amount",
    "nra_foundation_amount",
    "trevor_project_amount",
    "alliance_defending_freedom_amount",
    "duelgood_amount",
  ];

  // Track elements globally
  let elements, paymentElement;

  // Helper to check at least one $1+ donation
  function hasOneAboveOne() {
    return amountIds.some(
      (id) => parseFloat(document.getElementById(id).value) >= 1
    );
  }

  // Function to create PaymentIntent and mount PaymentElement
  async function setupPaymentElement() {
    // send form data to backend to create intent
    const formData = new FormData(form);
    const res = await fetch("/api/donations", {
      method: "POST",
      body: formData,
    });

    const { clientSecret, error } = await res.json();
    if (error) {
      paymentErrors.textContent = error;
      return false;
    }

    elements = stripe.elements({ clientSecret });
    paymentElement = elements.create("payment");
    paymentElement.mount("#payment-element");
    return true;
  }

  // Initial setup when page loads
  if (hasOneAboveOne()) {
    await setupPaymentElement();
  }

  // Re-create PaymentIntent if donation amounts change
  amountIds.forEach((id) => {
    document.getElementById(id).addEventListener("input", async () => {
      if (hasOneAboveOne()) {
        await setupPaymentElement();
      }
    });
  });

  // Final form submit = confirm the payment
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    paymentErrors.textContent = "";

    if (!hasOneAboveOne()) {
      paymentErrors.textContent =
        "Please enter at least one donation amount of $1 or more.";
      return;
    }

    if (!elements || !paymentElement) {
      const ok = await setupPaymentElement();
      if (!ok) return;
    }

    const { error } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: "https://duelgood.org/thank-you",
      },
    });

    if (error) {
      paymentErrors.textContent = error.message;
    }
  });
});
