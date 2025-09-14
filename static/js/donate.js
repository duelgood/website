document.addEventListener("DOMContentLoaded", function () {
  const form = document.getElementById("donation-form");
  const paymentErrors = document.getElementById("card-errors"); // reuse this div

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

  form.addEventListener("submit", function (e) {
    e.preventDefault();

    setTimeout(async () => {
      // ---- 1. Validate donation amounts ----
      const hasOneAboveOne = amountIds.some(
        (id) => parseFloat(document.getElementById(id).value) >= 1
      );
      if (!hasOneAboveOne) {
        paymentErrors.textContent =
          "Please enter at least one donation amount of $1 or more.";
        return;
      }

      try {
        // ---- 2. Collect form data ----
        const formData = new FormData(form);

        // ---- 3. Create PaymentIntent on backend ----
        const response = await fetch("/api/donations", {
          method: "POST",
          body: formData,
        });

        const { clientSecret, error } = await response.json();
        if (error) {
          paymentErrors.textContent = error;
          return;
        }

        // ---- 4. Mount Payment Element ----
        const elements = stripe.elements({ clientSecret });
        const paymentElement = elements.create("payment");
        paymentElement.mount("#card-element");

        // ---- 5. Confirm payment ----
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
    }, 0);
  });
});
