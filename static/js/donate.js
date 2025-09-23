document.addEventListener("DOMContentLoaded", function () {
  const form = document.getElementById("donation-form");
  const paymentErrors = document.getElementById("payment-errors");
  const stripe = Stripe(
    "pk_test_51S5FMtPaAbpNU2MW6IFPfy7uuVlvMcfDkJmI6xpUEd8AC8VvkwwO87PGhUlfUkPEmio4i3LnDgygBkpl5X68hCSj00SD13F37u"
  );
  let elements; // Define elements in a broader scope

  const amountIds = [
    "planned_parenthood_amount",
    "national_right_to_life_committee_amount",
    "everytown_for_gun_safety_amount",
    "nra_foundation_amount",
    "trevor_project_amount",
    "alliance_defending_freedom_amount",
    "duelgood_amount",
  ];

  function enforceMinZero() {
    // This part is fine.
  }
  enforceMinZero();

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
      // 1. Send donor info + donation amounts to backend -> PaymentIntent
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

      // 2. Mount Payment Element with the client secret
      elements = stripe.elements({ clientSecret });
      const paymentElement = elements.create("payment");
      paymentElement.mount("#payment-element");

      // 3. Attach a new submit listener to the form to confirm the payment
      form.removeEventListener("submit", arguments.callee); // Remove the old listener
      form.addEventListener("submit", async function (e) {
        e.preventDefault();
        const { error: stripeError } = await stripe.confirmPayment({
          elements,
          confirmParams: {
            return_url: "https://duelgood.org/thank-you",
          },
        });
        if (stripeError) {
          paymentErrors.textContent = stripeError.message;
        }
      });
      // Programmatically submit the form to trigger the new listener
      form.submit();
    } catch (err) {
      console.error("Donation error:", err);
      paymentErrors.textContent =
        "An unexpected error occurred. Please try again.";
    }
  });
});
